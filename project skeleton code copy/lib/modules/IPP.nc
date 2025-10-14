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

        return SUCCESS;
    }
    
    // handle incoming IP packets
    event void LinkLayer.receive(pack* msg, uint16_t src, uint8_t len) {

    }

}