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

    // Send a message using SimpleSend
    command error_t Flooding.send(uint16_t dest, message_t* msg, uint8_t len) {
        FloodingHdr* header = (FloodingHdr*)call LinkLayer.getPayload(msg, len);

        // Initialize the header
        header->src = TOS_NODE_ID;
        header->seq = call Random.rand16();
        header->hop = 0;

        // Send the message
        return call SimpleSend.send(msg, dest);
    }

    // Create Node Table
    #define MAX_NODES 20                // Max number of nodes in network
    uint16_t nodeTable[MAX_NODES];      // Node Table as Array
    uint8_t nodeCount = 0;              // CURRENT number of nodes in table

    // FUNCTION to check if a node is already in the table
    bool isNodeInTable(uint16_t nodeID) {
        for (uint8_t i = 0; i < nodeCount; i++) {
            if (nodeTable[i] == nodeID) {
                return TRUE;
            }
        }
        return FALSE;
    }

    // FUNCTION to add node to the table
    void addNode(uint16_t nodeID){
        
        // Add node to table
        if (nodeCount < MAX_NODES) {
            if(!isNodeInTable(nodeID)) { 
                nodeTable[nodeCount++] = nodeID;    // Increases node count while adding it to table.
            }
        }
    }




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
    // 
}