#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module IPP{ 
    provides interface IP; 
    provides interface Receive[uint8_t protocol_id]; // <-- ADD THIS LINE

    uses interface LinkState;
    uses interface LinkLayer;
    
}

implementation { 
    pack forwardBuffer;

    // send IP packets
    command error_t IP.send(pack* msg, uint16_t dest) { 
        // get next hop 
        uint16_t next_hop = call LinkState.getNextHop(dest);
        dbg(ROUTING_CHANNEL, "IPP: Sending packet at Node %d to Node %d via Next Hop %d\n", TOS_NODE_ID, dest, next_hop);

        if (next_hop != AM_BROADCAST_ADDR) { 
            return call LinkLayer.send(msg, next_hop);
        }

        call LinkState.printTable(); // print table upon failure
        return FAIL;
    }
    
    // handle incoming IP packets
    event void LinkLayer.receive(pack* msg, uint16_t src, uint8_t len) {

        if(msg->protocol != PROTOCOL_PING && msg->protocol != PROTOCOL_PINGREPLY) { 
            return;
        }

        if(msg->dest == TOS_NODE_ID) { 
            // it's for us
            dbg(ROUTING_CHANNEL, "IPP: Packet received for me at Node %d from Node %d\n", TOS_NODE_ID, src);
            signal Receive.receive[msg->protocol](NULL, msg, len);
        } else { 

            // forward it 
            dbg(ROUTING_CHANNEL, "IPP: Forwarding packet at Node %d from Node %d to Node %d\n", TOS_NODE_ID, src, msg->dest);
            if (msg->TTL > 0) {
                // ask LinkState for the next hop from this node
                uint16_t next_hop = call LinkState.getNextHop(msg->dest);
                memcpy(&forwardBuffer, msg, sizeof(pack));
                forwardBuffer.TTL--;

                msg->TTL--; // decrement TTL
                
                // Forward the packet if next_hop is valid and not the source
                if (next_hop != AM_BROADCAST_ADDR && next_hop != src) {
                    call LinkLayer.send(&forwardBuffer, next_hop);
                }
            }

        }



    }

    // drop packets without ping protocols
    default event message_t* Receive.receive[uint8_t protocol_id](message_t* msg, void* payload, uint8_t len) {
        return msg;
    }

}