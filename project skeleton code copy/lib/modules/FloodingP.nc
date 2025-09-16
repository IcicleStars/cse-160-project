/** 
Notes:
to broadcast to all nodes, use AM_BROADCAST_ADDR

**/

#include "../../includes/FloodingHdr.h"
#include "../../includes/packet.h"

module FloodingP{ 
    provides interface Flooding; 
    uses { 
        interface Timer<TMilli>; 
        interface Random;
        interface LinkLayer;

    }
}

implementation { 
    
    event void LinkLayer.receive(pack* msg, uint16_t src) { 

    }

    command error_t Flooding.send(pack msg, uint16_t dest) { 
        return call LinkLayer.send(msg, dest);
    }   
    
    // Timer fired event
    event void Timer.fired() {
        // Logic for handling timer events can be added here
    }

    // // Create Node Table
    // #define MAX_NODES 20                // constant max number of nodes in network
    // uint16_t nodeTable[MAX_NODES];      // Node Table as Array
    // uint8_t nodeCount = 0;              // CURRENT number of nodes in table

    // // FUNCTION to check if a node is already in the table
    // bool isNodeInTable(uint16_t nodeID) {
    //     for (uint8_t i = 0; i < nodeCount; i++) {
    //         if (nodeTable[i] == nodeID) {
    //             return TRUE;
    //         }
    //     }
    //     return FALSE;
    // }

    // // FUNCTION to add node to the table
    // void addNode(uint16_t nodeID){
        
    //     // Add node to table
    //     if (nodeCount < MAX_NODES) {
    //         if(!isNodeInTable(nodeID)) { 
    //             nodeTable[nodeCount++] = nodeID;    // Increases node count while adding it to table.
    //         }
    //     }
    // }




    // ICE NOTES as we go: 
    // - make sure interface uses are correct
    // - Add error fommand to interface 
    // - worry about logic once things are created and actually wired/connected stop worrying about that please
    // - make timer fire event
    // - Add random 
    // - 

    // Questions to ask: 
    // - Where to make node table? 
    // - makefile errors
    // - IF IT TAKES INPUT, use simplesend as template for flooding
}