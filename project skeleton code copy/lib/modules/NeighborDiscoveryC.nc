#include "../../includes/am_types.h"

configuration NeighborDiscoveryC{
   provides interface NeighborDiscovery;
}

implementation{

   components NeighborDiscoveryP;
   NeighborDiscovery = NeighborDiscoveryP;

   components new TimerMilliC() as neighborTimer;
   //NeighborDiscoveryP.neighborTimer -> neighborTimer; 

   components RandomC as Random; 
   //NeighborDiscoveryP.Random -> Random; 

   // Radio components
   components new AMSenderC(AM_PACK) as AmSend;
   components new AMReceiverC(AM_PACK) as packetReceive;
   //NeighborDiscoveryP.Receive -> packetReceive;

   // Wire the components
   // NeighborDiscoveryP -> MainC;
   NeighborDiscoveryP.neighborTimer -> neighborTimer; 
   NeighborDiscoveryP.Random -> Random;
   NeighborDiscoveryP.Packet -> AmSend;

   NeighborDiscoveryP.AMSend -> AmSend;
   NeighborDiscoveryP.Receive -> packetReceive;


}