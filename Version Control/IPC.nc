#include "../../includes/am_types.h"

configuration IPC{
   provides interface IP;
}

implementation{
    // create IP
    components IPP as IPP;
    IP = IPP;

    // use LinkState
    components LinkStateC;
    IPP.LinkState -> LinkStateC;

    // use LinkLayer
    components LinkLayerC;
    IPP.LinkLayer -> LinkLayerC;

}