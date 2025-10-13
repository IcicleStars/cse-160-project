#include "../../includes/am_types.h"

configuration LinkStateC{
   provides interface Flooding;
}

implementation{
    // Create IP
    components IPP as IPP;
    IP = IPP;

    // Use LinkState
    components LinkStateC;
    IPP.LinkState = LinkStateC;

    // Use LinkLayer
    components LinkLayerC;
    IPP.LinkLayer -> LinkLayerC;

}