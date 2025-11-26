#include "../../includes/CommandMsg.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"

configuration TransportC { 
    provides interface Transport;
}

implementation { 
    components TransportP as TransportP;
    Transport = TransportP;

    components IPC as IP;
    TransportP.IP -> IP.IP;

    TransportP.Receive -> IP.Receive[PROTOCOL_TCP];

    components new TimerMilliC() as TimerC;
    TransportP.TCPTimer -> TimerC.Timer;

}