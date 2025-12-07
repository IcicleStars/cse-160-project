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
   uint8_t overflows = 0;

   // global variables for hello command
   uint8_t hello_username_buffer[CMD_PACKET_MAX_PAYLOAD_SIZE];
   uint8_t hello_username_len = 0;
   char my_username[MAX_USERNAME_LEN];

   // server fixed at node 1 and port 41
   #define SERVER_ADDR 1
   #define SERVER_PORT 41
   #define APP_CLIENT_PORT 42

   #define MAX_USERS 10
   #define MAX_USERNAME_LEN 16
   #define LISTUSER_CMD "listusr\r\n"
   #define LISTUSER_CMD_LEN (sizeof(LISTUSER_CMD) - 1)

   user_entry_t user_list[MAX_USERS];


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      listen_fd = 0;
      client_fd = 0;

      // START SERVER SETUP LOGIC ON NODE 1
      if(TOS_NODE_ID == SERVER_ADDR) { 
         socket_addr_t addr;
         addr.port = SERVER_PORT;
         addr.addr = TOS_NODE_ID;

         listen_fd = call Transport.socket(); 

         if (listen_fd != 0) { 
            if (call Transport.bind(listen_fd, &addr) == SUCCESS) { 
               if (call Transport.listen(listen_fd) == SUCCESS) { 
                  dbg(TRANSPORT_CHANNEL, "Node 1: Server listening on Port %u\n", SERVER_PORT);
                  call ServerTimer.startPeriodic(1000);
               } else { 
                  dbg(TRANSPORT_CHANNEL, "Node 1 server failed to listen\n");
               }
            } else { 
               dbg(TRANSPORT_CHANNEL, "Node 1 server failed to bind\n");
            }
         } else { 
            dbg(TRANSPORT_CHANNEL, "Node 1 server failed to create socket\n");
         }
      }

      dbg(GENERAL_CHANNEL, "Booted\n");
      call NeighborDiscovery.findNeighbors();
      // call neighborTimer.startOneShot(100 + (call Random.rand16() % 300));

      // initialize link state
      call LinkState.initialize();

      // start server setup


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
            (uint8_t*)myMsg->payload,    // payload
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

   void print_buffer(uint8_t* buff, uint16_t len) { 
      uint16_t i;
      uint16_t dataBeingRead;

      dbg(TRANSPORT_CHANNEL, "Reading Data: ");
      for (i = 0; i < len; i++) { 
         dataBeingRead = buff[i] + (256 * overflows);

         if (i == len - 1) { 
            dbg_clear(TRANSPORT_CHANNEL, "%hu\n", dataBeingRead);
         } else { 
            dbg_clear(TRANSPORT_CHANNEL, "%hu ", dataBeingRead);
         }

         if(buff[i] >= 255) { 
            overflows++;
         }
      }

   }

   uint16_t format_user_reply(uint8_t *buffer) { 
      uint8_t i;
      uint16_t len;
      uint8_t prefix_len;
      const char *prefix = "listUsrRply ";
      len = 0;
      prefix_len = strlen(prefix);

      memcpy(buffer, prefix, prefix_len);
      len += prefix_len;

      for (i = 0; i < MAX_USERS; i++) { 
         if (user_list[i].used) { 
            uint8_t user_len = strlen(user_list[i].username);
            if (len + user_len + 3 >= SOCKET_BUFFER_SIZE) { 
               break;
            }
            memcpy(buffer + len, user_list[i].username, user_len);
            len += user_len;
            buffer[len++] = ' ';
         }
      }

      if (len > prefix_len) { 
         len--;
      } 
      buffer[len++] = '\r';
      buffer[len++] = '\n';
      return len;

   }

   // ICE COME BACK TO THIS
   socket_t find_socket_by_name(char* username) { 

      uint8_t i;
      for(i = 0; i < MAX_USERS; i++) { 
         if (user_list[i].used && strcmp(user_list[i].username, username) == 0) { 
            return user_list[i].fd;
         }
      }

      return 0;
   }

   char* find_name_by_socket(socket_t fd) { 
      uint8_t i;
      for(i = 0; i < MAX_USERS; i++) { 
         if (user_list[i].used && user_list[i].fd == fd) { 
            return user_list[i].username;
         }
      }

      return "Unknown";

   }

   event void ServerTimer.fired() {
      socket_t new_fd;
      uint8_t i;
      
      if(listen_fd == 0) {
         return;
      }

      new_fd = call Transport.accept(listen_fd);

      if (new_fd > 0 && accepted_count < MAX_NUM_OF_SOCKETS) {
         dbg(TRANSPORT_CHANNEL, "Node: Server accepted new connection\n");
         accepted_fds[accepted_count] = new_fd;
         accepted_count++;
      }

      // process data
      for (i = 0; i < accepted_count; i++) {
         uint16_t bytes_read = call Transport.read(accepted_fds[i], read_buffer, SOCKET_BUFFER_SIZE);
         
         if (bytes_read > 0) {
            // null-terminate buff
            char* input;
            read_buffer[bytes_read] = '\0';
            input = (char*)read_buffer;

            dbg(TRANSPORT_CHANNEL, "Server read %u bytes from FD %u: %s\n", bytes_read, accepted_fds[i], input);

            // check for LISTUSR
            if (strncmp(input, LISTUSER_CMD, LISTUSER_CMD_LEN) == 0) {
                uint8_t reply_buffer[SOCKET_BUFFER_SIZE];
                uint16_t reply_len = format_user_reply(reply_buffer);
                call Transport.write(accepted_fds[i], reply_buffer, reply_len);
            }
            
            // check for BROADCAST
            else if (strstr(input, "msg ") == input) {
               char broadcast_buffer[SOCKET_BUFFER_SIZE];
               char* content = input + 4; // Skip "msg "
               char* sender_name = find_name_by_socket(accepted_fds[i]);
               uint8_t k;

               sprintf(broadcast_buffer, "%s: %s\r\n", sender_name, content);
               dbg(GENERAL_CHANNEL, "SERVER: Broadcasting: %s", broadcast_buffer);
               
               // broadcast
               for(k = 0; k < accepted_count; k++) {
                  call Transport.write(accepted_fds[k], (uint8_t*)broadcast_buffer, strlen(broadcast_buffer));
               }
            }

            // check for UNICAST
            else if (strstr(input, "whisper ") == input) {
               char target_name[20];
               char* message_ptr;
               char whisper_buffer[SOCKET_BUFFER_SIZE];
               socket_t target_fd;
               char* params = input + 8; // skip "whisper "
               int name_len = 0;

               // parse username
               while(params[name_len] != ' ' && params[name_len] != '\0') {
                  target_name[name_len] = params[name_len];
                  name_len++;
               }
               target_name[name_len] = '\0';
               message_ptr = params + name_len + 1;

               dbg(GENERAL_CHANNEL, "SERVER: Whisper detected for %s\n", target_name);
               
               target_fd = find_socket_by_name(target_name);
               if (target_fd != 0) {
                  char* sender_name = find_name_by_socket(accepted_fds[i]);
                  sprintf(whisper_buffer, "%s\r\n", message_ptr);
                  call Transport.write(target_fd, (uint8_t*)whisper_buffer, strlen(whisper_buffer));
               } else {
                  dbg(TRANSPORT_CHANNEL, "SERVER: User %s not found\n", target_name);
               }
            }

            // HELLO CHECK
            else if (read_buffer[bytes_read - 1] == '\0') {
                uint8_t j;
                uint8_t len = (bytes_read < MAX_USERNAME_LEN) ? bytes_read : MAX_USERNAME_LEN;
                
                for (j = 0; j < MAX_USERS; j++) {
                    if (user_list[j].used == 0) {
                        user_list[j].used = 1;
                        user_list[j].fd = accepted_fds[i];
                        memcpy(user_list[j].username, read_buffer, len);
                        user_list[j].username[len - 1] = '\0';
                        dbg(TRANSPORT_CHANNEL, "Server: Registered user '%s' on FD %u.\n", user_list[j].username, accepted_fds[i]);
                        break;
                    }
                }
            }
         }
         
         // check for closed connections
         if (call Transport.getState(accepted_fds[i]) == CLOSE_WAIT) {
             uint8_t j;
             dbg(TRANSPORT_CHANNEL, "Node: Client on %u closed.\n", accepted_fds[i]);
             
             // remove user
             for (j = 0; j < MAX_USERS; j++) {
                 if (user_list[j].used && user_list[j].fd == accepted_fds[i]) {
                     user_list[j].used = 0;
                     user_list[j].fd = 0;
                     break;
                 }
             }
             call Transport.close(accepted_fds[i]);
             
             // remove from accepted list
             for(j = i; j < accepted_count - 1; j++) {
                 accepted_fds[j] = accepted_fds[j+1];
             }
             accepted_count--;
             i--; 
         }
      }
   }

   event void ClientTimer.fired() { 
   //  uint16_t bytes_to_send;
   //  uint16_t i;

    if(client_fd == 0) { return; }

    // ********** 1. HELLO COMMAND LOGIC (Higher Priority) **********
    if (hello_username_len > 0) {
        // If the connection is ESTABLISHED, send the one-time message
        if (call Transport.getState(client_fd) == ESTABLISHED) {
            dbg(TRANSPORT_CHANNEL, "Node: Hello connection ESTABLISHED. Sending username '%s'.\n", (char*)hello_username_buffer);
            
            // Attempt to write the data
            if (call Transport.write(client_fd, hello_username_buffer, hello_username_len) > 0) { 
                // Success: Clear buffer, stop timer, close connection
               //  dbg(TRANSPORT_CHANNEL, "Node: Hello data successfully written. Closing socket.\n");
                hello_username_len = 0;
               //  call ClientTimer.stop();
               //  call Transport.close(client_fd); 
               //  client_fd = 0;
            } else {
               //  dbg(TRANSPORT_CHANNEL, "Node: Write buffer full, retrying hello send.\n");
            }
        }
      //   return; // Exit here if we are processing a hello command
    }
    // ********** END HELLO COMMAND LOGIC **********

   // receive logic

   if (client_fd != 0 && call Transport.getState(client_fd) == ESTABLISHED) { 
      uint16_t bytes_read = call Transport.read(client_fd, read_buffer, SOCKET_BUFFER_SIZE);

      if (bytes_read > 0) { 
         read_buffer[bytes_read] = '\0';

         dbg(GENERAL_CHANNEL, "%s Received: %s", my_username, read_buffer);
      }

   }
    
    // ********** 2. TEST DATA WRITE LOGIC **********

   //  // Check if the client socket is ESTABLISHED for large data transfer
   //  if(call Transport.getState(client_fd) != ESTABLISHED) { 
   //     dbg(TRANSPORT_CHANNEL, "Node: Client socket not yet established, waiting to write test data.\n");
   //     return;
   //  }

   //  // Check if total data transfer is complete
   //  if(data_sent_count >= total_data_to_send) { 
   //     call ClientTimer.stop();
   //     dbg(TRANSPORT_CHANNEL, "Node: Client done sending %u bytes. Closing socket.\n", total_data_to_send);
   //     call Transport.close(client_fd); // Close connection after test is complete
   //     client_fd = 0;
   //     return;
   //  }

    // Calculate remaining bytes to send
   //  bytes_to_send = total_data_to_send - data_sent_count;

    // Limit send size to one segment (MAX_TCP_DATA)
   //  if(bytes_to_send > MAX_TCP_DATA) { 
   //     bytes_to_send = MAX_TCP_DATA;
   //  }

   //  // Generate deterministic test data (i.e., sequence numbers)
   //  for(i = 0; i < bytes_to_send; i++) { 
   //     write_buffer[i] = (data_sent_count + i) % 256;
   //  }
    
   //  // Attempt to write the test data
   //  if (call Transport.write(client_fd, write_buffer, bytes_to_send) > 0) { 
   //     data_sent_count += bytes_to_send;
   //     dbg(TRANSPORT_CHANNEL, "Node: Client wrote %hu bytes, total sent is %hu\n", bytes_to_send, data_sent_count);
   //  } else { 
   //     // If the Transport layer buffer is full, the timer will fire again later to retry.
   //     dbg(TRANSPORT_CHANNEL, "Node: Client write buffer is full (Congestion/Flow Control), trying again.\n");
   //  }

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

   event void CommandHandler.hello(uint16_t destination, uint16_t clientPort, uint8_t *username) {
    socket_addr_t my_addr;
    socket_addr_t dest_addr;
    uint8_t username_length = strlen((char*)username) + 1;

    if (username_length <= MAX_USERNAME_LEN) { 
      memcpy(my_username, username, username_length);
    } else { 
      memcpy(my_username, username, MAX_USERNAME_LEN - 1);
      my_username[MAX_USERNAME_LEN - 1] = '\0';
    }

    // 1. Setup Addresses
    // The server destination is fixed at Node 1 (SERVER_ADDR) and Port 41 (SERVER_PORT)
    dest_addr.port = SERVER_PORT;
    dest_addr.addr = SERVER_ADDR;

    // The client's source address is the current node and the port provided by the user
    my_addr.port = (uint8_t)clientPort;
    my_addr.addr = TOS_NODE_ID;

    // 2. Create and Bind Socket (using client_fd from Node.nc)
    client_fd = call Transport.socket();
    if (client_fd == 0) {
        dbg(TRANSPORT_CHANNEL, "Node: FAILED to create client socket for hello\n");
        return;
    }

    if (call Transport.bind(client_fd, &my_addr) != SUCCESS) {
        dbg(TRANSPORT_CHANNEL, "Node: FAILED to bind client socket for hello\n");
        call Transport.close(client_fd); // Clean up
        client_fd = 0;
        return;
    }

    // 3. Attempt Connection
    dbg(TRANSPORT_CHANNEL, "Node: Client attempting connect to Node %u:%u\n", SERVER_ADDR, SERVER_PORT);

    if (call Transport.connect(client_fd, &dest_addr) != SUCCESS) {
        dbg(TRANSPORT_CHANNEL, "Node: FAILED to start connect for hello\n");
        call Transport.close(client_fd);
        client_fd = 0;
        return;
    }
    
    // 4. Send Data (Asynchronous Buffering)
    // The connection is now in SYN_SENT state, buffer the data to be sent later.

    if (username_length > 0 && username_length <= CMD_PACKET_MAX_PAYLOAD_SIZE) {
        // Copy username to the buffer
        memcpy(hello_username_buffer, username, username_length);
        hello_username_len = username_length;
        dbg(TRANSPORT_CHANNEL, "Node: Connect started. Username '%s' buffered to be sent upon ESTABLISHED.\n", (char*)username);
        
        // Start the client timer to periodically check if the connection is ready to send
        call ClientTimer.startPeriodic(500); // Use a shorter period (e.g., 500ms) for quick connection check
    } else {
        dbg(TRANSPORT_CHANNEL, "Node: Username too long or empty, connection aborted.\n");
        call Transport.close(client_fd);
        client_fd = 0;
    }

   }

   event void CommandHandler.setAppServer(){ 

      socket_addr_t addr;
    
      // 1. Setup Fixed Server Address and Port (Port 41, this node's ID)
      addr.port = SERVER_PORT; // SERVER_PORT is defined as 41
      addr.addr = TOS_NODE_ID;

      // Check if the server socket is already open (listen_fd != 0)
      if (listen_fd != 0) {
         dbg(TRANSPORT_CHANNEL, "Node: App Server already running on FD %u\n", listen_fd);
         return; // Server is already set up
      }

      // 2. Create Socket
      listen_fd = call Transport.socket();
      if (listen_fd == 0) {
         dbg(TRANSPORT_CHANNEL, "Node: App Server FAILED to create socket\n");
         return;
      }

    // 3. Bind to Port 41
      if   (call Transport.bind(listen_fd, &addr) != SUCCESS) {
         dbg(TRANSPORT_CHANNEL, "Node: App Server FAILED to bind to Port %u\n", SERVER_PORT);
         call Transport.close(listen_fd);
         listen_fd = 0;
         return;
      }

      // 4. Start Listening
      if (call Transport.listen(listen_fd) != SUCCESS) {
         dbg(TRANSPORT_CHANNEL, "Node: App Server FAILED to start listening\n");
         call Transport.close(listen_fd);
         listen_fd = 0;
         return;
      }

      // 5. Start Periodic Accept Timer
      call ServerTimer.startPeriodic(1500); // Check for incoming connections every 1 second
    
      dbg(TRANSPORT_CHANNEL, "Node: App Server successfully set up on Port %u\n", SERVER_PORT);

   }

   event void CommandHandler.setAppClient(){

      socket_addr_t my_addr;
      socket_addr_t dest_addr;

      // 1. Setup Addresses
      // The server destination is fixed at Node 1 (SERVER_ADDR) and Port 41 (SERVER_PORT)
      dest_addr.port = SERVER_PORT;
      dest_addr.addr = SERVER_ADDR;

      // The client's source address is the current node and a fixed application client port
      my_addr.port = APP_CLIENT_PORT;
      my_addr.addr = TOS_NODE_ID;

      // Reset data transfer counters for the new test
      data_sent_count = 0;
      total_data_to_send = 1000; // Define a large amount of test data to send

      // 2. Create Socket
      client_fd = call Transport.socket();
      if (client_fd == 0) {
         dbg(TRANSPORT_CHANNEL, "Node: FAILED to create App Client socket\n");
         return;
      }

      // 3. Bind to App Client Port (e.g., Port 42)
      if (call Transport.bind(client_fd, &my_addr) != SUCCESS) {
         dbg(TRANSPORT_CHANNEL, "Node: FAILED to bind App Client socket to Port %u\n", APP_CLIENT_PORT);
         call Transport.close(client_fd);
         client_fd = 0;
         return;
      }

      // 4. Connect to App Server (Node 1:Port 41)
      if (call Transport.connect(client_fd, &dest_addr) != SUCCESS) {
         dbg(TRANSPORT_CHANNEL, "Node: FAILED to start connect for App Client\n");
         call Transport.close(client_fd);
         client_fd = 0;
         return;
      }

      // 5. Start Client Timer to begin large data transfer upon ESTABLISHED
      dbg(TRANSPORT_CHANNEL, "Node: App Client attempting connection to Node %u:%u. Starting Client Timer.\n", SERVER_ADDR, SERVER_PORT);
      call ClientTimer.startPeriodic(5000); // 5-second interval for test client

   }

   event void CommandHandler.broadcastMessage(uint8_t *payload) { 

      uint16_t len;
      char* cmd = "msg ";
      char packet_buffer[SOCKET_BUFFER_SIZE];

      dbg(GENERAL_CHANNEL, "%s: Sending Broadcast MSG: %s\n", my_username, payload);

      // check connection
      if(client_fd == 0 || call Transport.getState(client_fd) != ESTABLISHED) { 
         dbg(GENERAL_CHANNEL, "%s: Cannot send msg due to lack of connection\n", my_username);
         return;
      }

      // format message
      sprintf(packet_buffer, "%s%s\r\n", cmd, (char*)payload);
      len = strlen(packet_buffer);
      
      call Transport.write(client_fd, (uint8_t*)packet_buffer, len);

   }

   event void CommandHandler.unicastMessage(uint8_t *username, uint8_t *message){ 

      uint16_t len;
      char packet_buffer[SOCKET_BUFFER_SIZE];

      dbg(GENERAL_CHANNEL, "%s: Sending Whisper to %s: %s\n", my_username, username, message);

      if (client_fd == 0 || call Transport.getState(client_fd) != ESTABLISHED) { 
         dbg(GENERAL_CHANNEL, "%s: Cannot whisper, not connected!\n", my_username);
         return;
      }

      sprintf(packet_buffer, "whisper %s %s\r\n", (char*)username, (char*)message);
      len = strlen(packet_buffer);

      call Transport.write(client_fd, (uint8_t*)packet_buffer, len);

   }

   event void CommandHandler.listUsers() { 
      uint16_t len;
      char* cmd = "listusr\r\n";
      len = strlen(cmd);

      if(client_fd == 0 || call Transport.getState(client_fd) != ESTABLISHED) { 
         dbg(GENERAL_CHANNEL, "Cannot print users. %s Not connected.\n", my_username);
         return;
      }

      call Transport.write(client_fd, (uint8_t*)cmd, len);
      dbg(GENERAL_CHANNEL, "%s: Requesting user list...\n", my_username);

   }

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }



}
