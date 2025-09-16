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
    command error_t LinkLayer.send(pack msg, uint16_t dest) { 
        return call SimpleSend.send(msg, dest);
    }

    // Notify of received message
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) { 
        return msg;
    }

    // AMControl interface methods
    event void AMControl.startDone(error_t err) { 

    }
    event void AMControl.stopDone(error_t err) { 

    }

    // LinkLayerHdr hdr;
    // hdr.src = get_local_address();
    // hdr.dest = get_remote_address();

}