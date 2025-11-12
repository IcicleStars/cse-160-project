#include "../../includes/am_types.h"

configuration LinkStateC{
   provides interface LinkState;
}

implementation{
    components LinkStateP as LinkStateP;
    LinkState = LinkStateP;

    // use Flooding
    components FloodingC;
    LinkStateP.Flooding -> FloodingC;

    // use NeighborDiscovery
    components NeighborDiscoveryC;
    LinkStateP.NeighborDiscovery -> NeighborDiscoveryC;

    // Use Timer
    components new TimerMilliC() as initialDijkstraTimer;
    LinkStateP.initialDijkstraTimer -> initialDijkstraTimer;


}