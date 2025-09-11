/** 
Notes:
to broadcast to all nodes, use AM_BROADCAST_ADDR

**/

#include "../../includes/FloodingHdr.h"

generic module FloodingP{ 
    provides interface Flooding; 
    uses { 
        interface SimpleSend;
        interface Receive;
        interface Timer<TMilli>; 
        interface Random;
        interface LinkLayer;
    }
}

implementation { 

    // Access Flooding Header
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        FloodingHdr* header = (FloodingHdr*)payload; // typecast

        // Detect if message is new or is duplicate


        return msg; // Return the message
    }

    // Create Node Table for duplicate detection
    // Use LinkLayer to avoid sending message back to source nodes



    // ICE NOTES as we go: 
    // - make sure interface uses are correct
    // - Add error fommand to interface 
    // - add accessibility to structure in Flooding.h 
    // - worry about logic once things are created and actually wired/connected stop worrying about that please
}