#include "../../includes/am_types.h"

configuration LinkStateC{
   provides interface Flooding;
}

implementation{
   // AM_FLOODING = 10 based on am_types

    components LinkStateP as LinkStateP;
    LinkState = LinkStateP;

    // Use Flooding
    components FloodingC;
    LinkStateP.Flooding -> FloodingC;

    // Use NeighborDiscovery
    components NeighborDiscoveryC;
    LinkStateP.NeighborDiscovery -> NeighborDiscoveryC;

    // Use LinkLayer
    // components LinkLayerC;
    // LinkStateP.LinkLayer -> LinkLayerC;

}