#include "../../includes/packet.h"
#include "../../includes/LinkLayerHdr.h"
#include "../../includes/protocol.h"

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
        
        return call SimpleSend.send(msg, dest);

    }

    // Notify of received message
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) { 

        // cast payload to a pack
        pack* incoming = (pack*) payload;


        // signal higher layer that a packet is received
        signal LinkLayer.receive(incoming, incoming->src, len);

        // return original message
        return msg;
    }


// Ensure radio turns on
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