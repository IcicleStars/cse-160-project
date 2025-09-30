#include "../../includes/packet.h"
#include "../../includes/LinkLayerHdr.h"

module LinkLayerP{ 
    provides interface LinkLayer;
    uses { 
        interface SimpleSend;
        interface Receive;
        interface SplitControl as AMControl;
    }
}

implementation { 

    // Send message
    command error_t LinkLayer.send(pack *msg, uint16_t dest) { 
        

        // dbg(GENERAL_CHANNEL, "Link Layer sending packet from %hu to %hu\n", (unsigned short)msg->src, AM_BROADCAST_ADDR);

        return call SimpleSend.send(msg, dest);

    }

    // Notify of received message
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) { 

        // Cast the payload to a pack structure
        pack* incoming = (pack*) payload; 

        // Signal the higher layer that a packet has been received, passing the packet and its source
        signal LinkLayer.receive(incoming, incoming->src, len);

        // Return the original message
        return msg;
    }

    event void AMControl.startDone(error_t err) { 
        if (err == SUCCESS) {
            dbg(GENERAL_CHANNEL, "Linklayer AM started\n");
        } else {
            dbg(GENERAL_CHANNEL, "Linklayer AM not started\n");
        }
    }

    event void AMControl.stopDone(error_t err) { 
        if (err == SUCCESS) {
            dbg(GENERAL_CHANNEL, "Linklayer AM stopped\n");
        } else {
            dbg(GENERAL_CHANNEL, "Linklayer AM not stopped");
        }
    }


    // signal LinkLayer.receive((pack*) payload, hdr->source);

    // LinkLayerHdr hdr;
    // hdr.src = get_local_address();
    // hdr.dest = get_remote_address();

}