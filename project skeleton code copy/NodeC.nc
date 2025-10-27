/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    // components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node.Boot -> MainC.Boot;

    // Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    // components new SimpleSendC(AM_PACK);
    // Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    // allows Node to use neighbor discovery 
    components NeighborDiscoveryC; 
    Node.NeighborDiscovery -> NeighborDiscoveryC;

    // Allow node to use flooding
    // components FloodingC as Flooding;
    // Node.Flooding -> Flooding;

    // Allow node to use Link State Routing
    components LinkStateC as LinkState;
    Node.LinkState -> LinkState;

    // Allow node to use IP 
    components IPC as IP;
    Node.IP -> IP;
    Node.Receive -> IP.Receive[PROTOCOL_PING];
    Node.Receive -> IP.Receive[PROTOCOL_PINGREPLY];

}
