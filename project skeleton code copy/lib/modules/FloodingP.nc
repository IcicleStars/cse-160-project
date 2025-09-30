/** 
Notes:
to broadcast to all nodes, use AM_BROADCAST_ADDR

**/

#include "../../includes/FloodingHdr.h"
#include "../../includes/packet.h"

module FloodingP{ 
    provides interface Flooding; 
    uses { 
        interface LinkLayer;

    }
}

implementation { 
    #define MAX_CACHE = 20;         // Macro to define cache max
    static uint16_t localSeq = 0;
    
    command error_t Flooding.send(pack *msg, uint16_t dest) { 

        pack out;
        FloodingHdr* fh;
        uint8_t floodingHeaderSize = sizeof(FloodingHdr);
        dbg(FLOODING_CHANNEL, "flooding send start");

        memset(&out, 0, sizeof(pack));

        fh = (FloodingHdr*)out.payload;
        fh->source = TOS_NODE_ID;
        fh->seq_num = localSeq++;
        fh->ttl = MAX_TTL;

        memcpy(fh->payload, msg->payload, PACKET_MAX_PAYLOAD_SIZE);

        out.src = TOS_NODE_ID;
        out.dest = dest;
        out.protocol = msg->protocol;

        return call LinkLayer.send(&out, dest);
    }

    event void LinkLayer.receive(pack* msg, uint16_t src) { 
        FloodingHdr* fh = (FloodingHdr*) msg->payload;

        signal Flooding.receive(msg, fh->source);

        if(fh->ttl > 1) { 
            pack fwdPack;
            FloodingHdr* fwdFH;

            memcpy(&fwdPack, msg, sizeof(pack));
            fwdFH = (FloodingHdr*)fwdPack.payload;

            fwdFH->ttl--;
            fwdPack.src = TOS_NODE_ID;
            fwdPack.TTL = fwdFH->ttl;

            dbg(FLOODING_CHANNEL, "Node %hu: forwarding flood from %hu with new TTL: %hhu\n", TOS_NODE_ID, fwdFH->source, fwdFH->ttl);
            call LinkLayer.send(&fwdPack, AM_BROADCAST_ADDR);
        }

    }
 
}