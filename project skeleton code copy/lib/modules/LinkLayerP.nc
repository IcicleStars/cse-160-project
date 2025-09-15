#include "../../includes/LinkLayerHdr.h"

generic module LinkLayerP{ 
    provides interface LinkLayer;
    uses interface SimpleSend;
    uses interface Timer<TMilli>;
    uses interface Random;
}

implementation { 

    LinkLayerHdr hdr;
    hdr.src = get_local_address();
    hdr.dest = get_remote_address();

}