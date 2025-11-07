#include "../../includes/CommandMsg.h"
#include "../../includes/packet.h"

configuration TransportC { 
    provides interface Transport;
}

implementation { 
    components TransportP as TransportP;
    Transport = TransportP;

    components IPC as IP;
    TransportP.IP -> IP.IP;

    TransportP.Receive -> IP.Receive[PROTOCOL_TCP];

}