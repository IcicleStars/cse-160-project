#include "../../includes/am_types.h"
#include "../../includes/FloodingHdr.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module FloodingP{ 
    provides interface Flooding; 
    uses interface LinkLayer;
}
implementation { 
    #define MAX_SEEN 20
    pack floodingForwardBuffer;
    uint8_t seenCount = 0;
    static uint16_t localSeq = 0;   

    // Create seen table
    struct seen {
        uint16_t source;
        uint16_t seq_num;
    } seen[MAX_SEEN];

    // detect if node is already seen
    bool alreadySeen(uint16_t source, uint16_t seq_num) {
        uint8_t i;
        for (i = 0; i < seenCount; i++) {
            if (seen[i].source == source && seen[i].seq_num == seq_num) {
                // dbg(FLOODING_CHANNEL, "FP: This node has been seen already!\n");
                return TRUE;
            }
            // dbg(FLOODING_CHANNEL, "FP: This node has not been seen yet ");
        }
        return FALSE;
    }

    // add most recent seen node to table
    void addSeen(uint16_t source, uint16_t seq_num) {
        if (seenCount < MAX_SEEN) {
            seen[seenCount].source = source;
            seen[seenCount].seq_num = seq_num;
            seenCount++;
        } else {
            uint8_t insert = seq_num % MAX_SEEN; 
            seen[insert].source = source;
            seen[insert].seq_num = seq_num;
        }
    }
    
    // Send
    command error_t Flooding.send(pack *msg, uint16_t dest, uint8_t payload_length) { 
        // declarations
        pack out; 
        FloodingHdr* fh;
        uint8_t floodingHeaderSize = sizeof(FloodingHdr);
        // dbg(FLOODING_CHANNEL, "flooding send start\n");

        if(msg->protocol == PROTOCOL_PING || msg->protocol == PROTOCOL_PINGREPLY) { 
            return FAIL;
        }

        // set the contents of memory
        memset(&out, 0, sizeof(pack));

        // build header inside packet's payload area.
        fh = (FloodingHdr*)out.payload;
        fh->source = TOS_NODE_ID;
        fh->seq_num = localSeq;
        fh->ttl = MAX_TTL;

        // Copy the application payload after the header.
        memcpy(fh->payload, msg->payload, payload_length);
        
        // build header inside new packet
        out.src = TOS_NODE_ID;
        out.dest = dest;
        out.protocol = msg->protocol;

        // Add packet to seen cache
        addSeen(fh->source, fh->seq_num);
        localSeq++;

        // detect if destination node already has 
        dbg(FLOODING_CHANNEL, "Node %hu is starting flood\n", TOS_NODE_ID);
        return call LinkLayer.send(&out, AM_BROADCAST_ADDR);
    }

    event void LinkLayer.receive(pack* msg, uint16_t src, uint8_t payload_length) {
        FloodingHdr* fh = (FloodingHdr*)msg->payload;
        pack reply;
        // dbg(FLOODING_CHANNEL, "FP: receive starts\n");
        if(msg->protocol == PROTOCOL_PING || msg->protocol == PROTOCOL_PINGREPLY) { 
            return;
        }

        // Basic checks
        if (alreadySeen(fh->source, fh->seq_num)) { 
            return; 
        }

        // Process the packet: add to cache and signal the application layer
        addSeen(fh->source, fh->seq_num);
        // dbg(FLOODING_CHANNEL, "Node %hu: Received flood from Node %hu (seq %hu, TTL %hhu)\n", TOS_NODE_ID, fh->source, fh->seq_num, fh->ttl);

        // tell LinkState
        signal Flooding.receive(msg, fh->source);

        // Check if node is the destination
        if(msg->dest == TOS_NODE_ID) { 
            dbg(FLOODING_CHANNEL, "Packet reached destination. Processing ping from %hu\n", fh->source);

            return;

        } else { 

            // Forward the packet if TTL allows
            if (fh->ttl > 1) {
                FloodingHdr* fwdFH;
                
                // add packet contents to packet being forwarded
                memcpy(&floodingForwardBuffer, msg, sizeof(pack));
                fwdFH = (FloodingHdr*)floodingForwardBuffer.payload;
                fwdFH->ttl--;
                floodingForwardBuffer.src = TOS_NODE_ID; 
                floodingForwardBuffer.TTL = fwdFH->ttl;   // update the outer TTL 

                // send next packet
                dbg(FLOODING_CHANNEL, "Forwarding flood from %hu. New TTL: %hhu\n", fwdFH->source, fwdFH->ttl);
                call LinkLayer.send(&floodingForwardBuffer, AM_BROADCAST_ADDR);
            } else { 
                dbg(FLOODING_CHANNEL, "At Node %hu, TTL reached zero. Flooding ended.\n", TOS_NODE_ID);
            }

        }

    }
}