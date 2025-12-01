/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/FloodingHdr.h"
#include "includes/TCP.h"
#include "includes/socket.h"
#include <string.h>

module Node{
   uses interface Boot;
   uses interface NeighborDiscovery;
   // uses interface Flooding;
   uses interface IP;
   uses interface LinkState;
   // uses interface LinkLayer;
   
   uses interface Transport;
   
   uses interface SplitControl as AMControl;
   uses interface Receive;

   // uses interface SimpleSend as Sender;

   uses interface CommandHandler;
   uses interface Timer<TMilli> as ClientTimer;
   uses interface Timer<TMilli> as ServerTimer;
}

implementation{
   pack sendPackage;
   // sockets
   socket_t listen_fd;
   socket_t client_fd;
   socket_t accepted_fds[MAX_NUM_OF_SOCKETS];
   uint8_t accepted_count = 0;

   #define MAX_TCP_DATA (PACKET_MAX_PAYLOAD_SIZE - sizeof(tcp_header))
   // data transfer informaiton
   uint16_t data_sent_count = 0;
   uint16_t total_data_to_send = 1000;
   uint8_t write_buffer[MAX_TCP_DATA];
   uint8_t read_buffer[SOCKET_BUFFER_SIZE];


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
      call NeighborDiscovery.findNeighbors();
      // call neighborTimer.startOneShot(100 + (call Random.rand16() % 300));

      // initialize link state
      call LinkState.initialize();

      listen_fd = 0;
      client_fd = 0;

   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

// exists to prevent errors
   event void NeighborDiscovery.neighborTableUpdated() { 

   }

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      // dbg(NEIGHBOR_CHANNEL, "Packet Received\n");
      // dbg(GENERAL_CHANNEL, "Packet Received at Node %d\n", TOS_NODE_ID);
      // if(len==sizeof(pack)){
      //    pack* myMsg=(pack*) payload;
      //    // dbg(NEIGHBOR_CHANNEL, "Package Payload: %s\n", myMsg->payload);
      //    return msg;
      // } 
      // // dbg(NEIGHBOR_CHANNEL, "Unknown Packet Type %d\n", len);
      // return msg;

      pack* myMsg = (pack*) payload;
      if (len != sizeof(pack)) { 
         return msg; 
      }

      if(myMsg->protocol != PROTOCOL_PING && myMsg->protocol != PROTOCOL_PINGREPLY && myMsg->protocol != PROTOCOL_TCP) {
         return msg;
      }

      // Check the protocol
      if (myMsg->protocol == PROTOCOL_PINGREPLY) {
         // received reply
         dbg(GENERAL_CHANNEL, "Received PINGREPLY from Node %hu\n", myMsg->src);
         return msg;

      } else if (myMsg->protocol == PROTOCOL_PING) {
         uint8_t payload_len = strlen((char*)myMsg->payload) + 1;
         // received ping, send reply
         // print payload 

         dbg(GENERAL_CHANNEL, "Received PING from Node %hu with Payload: \"%s\", sending reply\n", myMsg->src, (char*)myMsg->payload);
         
         // // set protocol to PING_REPLY
         // myMsg->protocol = PROTOCOL_PINGREPLY;
         
         // // swap src and dest
         // myMsg->dest = myMsg->src;
         // myMsg->src = original_dest; 

         // length doesn't exceed buffer size
         if (payload_len > PACKET_MAX_PAYLOAD_SIZE) {
             payload_len = PACKET_MAX_PAYLOAD_SIZE;
         }

         makePack(&sendPackage,
            TOS_NODE_ID,        // src
            myMsg->src,        // dest
            MAX_TTL,           // TTL
            PROTOCOL_PINGREPLY, // protocol
            myMsg->seq,         // seq
            myMsg->payload,    // payload
            payload_len // length
         );

         // call LinkState.printTable();
         
         // send it back via the IP layer
         call IP.send(&sendPackage, sendPackage.dest); 
      }

      return msg;
   }


   // event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
   //    dbg(GENERAL_CHANNEL, "PING EVENT \n");
   //    makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
   //    call Sender.send(sendPackage, destination);
   // }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      uint8_t payload_length = strlen((char*)payload);
      dbg(GENERAL_CHANNEL, "PING EVENT \n");

      // create pack to hold payload
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, 0, payload, payload_length); 

      // call Sender.send(sendPackage, destination);
      if (call IP.send(&sendPackage, destination) != SUCCESS) { 
         // call LinkState.printTable();
         call LinkState.printLSA();
         dbg(GENERAL_CHANNEL, "Failed to send IP packet.\n");
      }

   }

   event void ServerTimer.fired() { 
      socket_t new_fd;
      uint8_t i;

      if(listen_fd == 0) { 
         return;
      }

      new_fd = call Transport.accept(listen_fd);

      if (new_fd > 0) { 
         if(accepted_count < MAX_NUM_OF_SOCKETS) 
         { 
            dbg(TRANSPORT_CHANNEL, "Node: Server accepted new connection\n");
            accepted_fds[accepted_count] = new_fd;
            accepted_count++;
         }
      }

      // read from all exisitng connections 
      i = 0;
      while (i < accepted_count) { 

         uint16_t bytes_read = call Transport.read(accepted_fds[i], read_buffer, SOCKET_BUFFER_SIZE);

         if (bytes_read > 0) { 
            // data received
            dbg(TRANSPORT_CHANNEL, "Server read %u bytes from FD %u\n", bytes_read, accepted_fds[i]);
            i++;
         } else { 
            // closed connection

            if (call Transport.getState(accepted_fds[i]) == CLOSE_WAIT) { 
               uint8_t j;
               dbg(TRANSPORT_CHANNEL, "Node: Client on %u closed. Closing server side\n", accepted_fds[i]);

               call Transport.close(accepted_fds[i]);
               for(j = i; j < accepted_count - 1; j++) { 
                  accepted_fds[j] = accepted_fds[j+1];
               }

               accepted_count--;
            } else { 
               // no new data
               i++;
            }
            
         }

      }

   }

   event void ClientTimer.fired() { 
      uint16_t bytes_to_send;
      uint16_t i;

      if(client_fd == 0) { return; }

      if(call Transport.getState(client_fd) != ESTABLISHED) { 
         dbg(TRANSPORT_CHANNEL, "not yet established, will not write\n");
         return;
      }

      if(data_sent_count >= total_data_to_send) { 
         call ClientTimer.stop();
         dbg(TRANSPORT_CHANNEL, "Node: CLient done sending %u bytes\n", total_data_to_send);

         return;
      }

      bytes_to_send = total_data_to_send - data_sent_count;

      if(bytes_to_send > MAX_TCP_DATA) { 
         bytes_to_send = MAX_TCP_DATA;
      }

      for(i = 0; i < bytes_to_send; i++) { 
         write_buffer[i] = (data_sent_count + i) % 256;
      }

      if (call Transport.write(client_fd, write_buffer, bytes_to_send) > 0) { 
         data_sent_count += bytes_to_send;
         dbg(TRANSPORT_CHANNEL, "Node: Client wrote %hu bytes, total sent is %hu\n", bytes_to_send, data_sent_count);
      } else { 
         dbg(TRANSPORT_CHANNEL, "Node: CLient write buffer is full, trying again\n");
      }

   }

   event void CommandHandler.printNeighbors(){ call NeighborDiscovery.printNeighbors(); }

   event void CommandHandler.printRouteTable(){ call LinkState.printTable(); }

   event void CommandHandler.printLinkState(){ call LinkState.printLSA(); }

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint16_t port){ 

      socket_addr_t addr;
      addr.port = (uint8_t)port;
      addr.addr = TOS_NODE_ID;

      listen_fd = call Transport.socket();
      if(listen_fd == 0) { 
         // failed to create socket
         return;
      }

      if (call Transport.bind(listen_fd, &addr) != SUCCESS) { 
         return;
      }

      if (call Transport.listen(listen_fd) != SUCCESS) { 
         return;
      }

      call ServerTimer.startPeriodic(1000);

   }

   event void CommandHandler.setTestClient(uint16_t dest, uint16_t srcPort, uint16_t destPort){ 

      socket_addr_t my_addr;
      socket_addr_t dest_addr;

      // set up local src addr
      my_addr.port = (uint8_t)srcPort;
      my_addr.addr = TOS_NODE_ID;

      // set up dest server address
      dest_addr.port = (uint8_t)destPort;
      dest_addr.addr = dest;

      client_fd = call Transport.socket();
      if (client_fd == 0) { 
         return;
      }

      // bind to port
      if (call Transport.bind(client_fd, &my_addr) != SUCCESS) { 
         dbg(TRANSPORT_CHANNEL, "Node (Transport): FAILED to bind client socket\n");
         return;
      }

      // connect to server
      if (call Transport.connect(client_fd, &dest_addr) != SUCCESS) { 
         dbg(TRANSPORT_CHANNEL, "Node (Transport): FAILED to start connect\n");
         return;
      }

      // begin client timer to send data
      call ClientTimer.startPeriodic(5000);

   }

   event void CommandHandler.closeClientSocket(uint16_t dest, uint16_t srcPort, uint16_t destPort){ 
      if (client_fd != 0) { 
         dbg(TRANSPORT_CHANNEL, "Node (Transport): Closing client socket (FD %u)\n", client_fd);

         // close
         if (call Transport.close(client_fd) == SUCCESS) { 
            client_fd = 0;
         } else { 
            dbg(TRANSPORT_CHANNEL, "Node (Transport): FAILED to close socket\n");
         }

      }
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }



}
