#include "../../includes/am_types.h"
#include "../../includes/FloodingHdr.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module LinkStateP{ 
    provides interface LinkState; 
    uses interface Flooding;
    uses interface NeighborDiscovery;
    // uses interface LinkLayer;
}

implementation { 
    
}