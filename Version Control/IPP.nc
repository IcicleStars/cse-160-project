#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module IPP{ 
    provides interface IP; 

    uses interface LinkState;
    uses interface LinkLayer;
}

implementation { 

    // send IP packets
    command error_t IP.send(pack* msg, uint16_t dest) { 
        // This command currently doesn't use the LinkState routing decision.
        // It should eventually call LinkLayer.send(msg, next_hop).
        return SUCCESS;
    }
    
    // === NEW: Event that listens for IP packets ===
    event void LinkLayer.receive(pack* incoming_pack, uint16_t src, uint8_t len) {
        

        // --- IP PROCESSING LOGIC GOES HERE ---

        // 1. Check if the packet is destined for this node (TOS_NODE_ID) or is a broadcast.
        if (incoming_pack->dest == TOS_NODE_ID || incoming_pack->dest == AM_BROADCAST_ADDR) {
            
            // 2. Demultiplex based on protocol type.
            switch (incoming_pack->protocol) {
                case PROTOCOL_PING:
                    // Signal the component that handles PING requests
                    break;
                case PROTOCOL_DV:
                case PROTOCOL_LINKSTATE:
                    // Signal the LinkState component here.
                    break;

                default:
                    dbg(GENERAL_CHANNEL, "IPP: Received unhandled protocol %hhu\n", incoming_pack->protocol);
                    break;
            }
            // For now, simply log the received packet at the IP layer.
            dbg(GENERAL_CHANNEL, "IPP: Received packet from %hu with protocol %hhu\n", 
                incoming_pack->src, incoming_pack->protocol);
        } else {
            // Forwarding Logic (Starts around source line 22 in the old block)
            if (incoming_pack->TTL > 1) {
                uint16_t next_hop;
                
                // Get Next Hop from LinkState Routing Table
                next_hop = call LinkState.getNextHop(incoming_pack->dest);
                
                if (next_hop != AM_BROADCAST_ADDR) {
                    // Decrement TTL and update source for debugging/loop prevention
                    incoming_pack->TTL--; 
                    
                    // Send packet to next hop via LinkLayer
                    if (call LinkLayer.send(incoming_pack, next_hop) == SUCCESS) {
                        dbg(GENERAL_CHANNEL, "IPP: Forwarded packet to %hu for Dest %hu\n", next_hop, incoming_pack->dest);
                    } else {
                        dbg(GENERAL_CHANNEL, "IPP: Failed to forward packet to %hu\n", next_hop);
                    }
                } else {
                    dbg(GENERAL_CHANNEL, "IPP: Destination %hu unreachable (no route found)\n", incoming_pack->dest);
                }
            } else {
                dbg(GENERAL_CHANNEL, "IPP: Packet dropped (TTL reached zero) for Dest %hu\n", incoming_pack->dest);
            }
        }
        
    }
    

}