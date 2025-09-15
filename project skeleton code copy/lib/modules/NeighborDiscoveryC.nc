#include "../../includes/am_types.h"

configuration NeighborDiscoveryC{
   provides interface NeighborDiscovery;
}

implementation{
   components new NeighborDiscoveryP as NeighborDiscovery
   NeighborDiscovery = SimpleSendP.SimpleSend;

   components new TimerMilliC() as neighborTimer;
   NeighborDiscoveryP.neighborTimer -> neighborTimer; 

   components RandomC as Random; 
   NeighborDiscoveryP.Random -> Random; 


}
