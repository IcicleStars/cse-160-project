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
#include <string.h>

module Node{
   uses interface Boot;
   uses interface NeighborDiscovery;
   // uses interface Flooding;
   uses interface IP;
   uses interface LinkState;
   // uses interface LinkLayer;
   
   uses interface SplitControl as AMControl;
   uses interface Receive;

   // uses interface SimpleSend as Sender;

   uses interface CommandHandler;
}

implementation{
   pack sendPackage;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
      call NeighborDiscovery.findNeighbors();
      // call neighborTimer.startOneShot(100 + (call Random.rand16() % 300));

      // initialize link state
      call LinkState.initialize();

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

      // Check the protocol
      if (myMsg->protocol == PROTOCOL_PINGREPLY) {
         // received reply
         dbg(GENERAL_CHANNEL, "Received PINGREPLY from Node %hu\n", myMsg->src);
         //

      } else if (myMsg->protocol == PROTOCOL_PING) {
         uint16_t original_dest = myMsg->dest;
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
            original_dest,        // src
            myMsg->src,        // dest
            MAX_TTL,           // TTL
            PROTOCOL_PINGREPLY, // protocol
            myMsg->seq,         // seq
            myMsg->payload,    // payload
            payload_len // length
         );
         
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
         dbg(GENERAL_CHANNEL, "Failed to send IP packet.\n");
      }

   }

   event void CommandHandler.printNeighbors(){ call NeighborDiscovery.printNeighbors(); }

   event void CommandHandler.printRouteTable(){ call LinkState.printTable(); }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

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

   // event void Flooding.receive(pack* msg, uint16_t src) {
   //    // Access payload for printing
   //    FloodingHdr* fh = (FloodingHdr*)msg->payload;
   //    char* str_payload = (char*)fh->payload;

   //    // Print message!
   //    dbg(FLOODING_CHANNEL, "Flooding message received from node %u: ", src);
   //    if(msg->protocol == PROTOCOL_PINGREPLY) { 
   //       dbg(FLOODING_CHANNEL, "Received PINGREPLY from Node %hu\n", src);
   //    } else { 
   //       dbg(FLOODING_CHANNEL, "Received PING from Node %hu with payload: \"%s\"\n", src, str_payload);
   //    }
   // }


}
