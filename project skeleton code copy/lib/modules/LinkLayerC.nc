#include "../../includes/am_types.h"
configuration LinkLayerC{ 
   provides interface LinkLayer;
}

implementation { 

   // Instantiate LinkLayerP
   components LinkLayerP;
   LinkLayer = LinkLayerP;

   // Create Receiver
   components new AMReceiverC(AM_LINKLAYER) as Receiver;
   LinkLayerP.Receive -> Receiver;

   components new SimpleSendC(AM_LINKLAYER) as Sender;
   LinkLayerP.SimpleSend -> Sender.SimpleSend;

   components ActiveMessageC;
   LinkLayerP.AMControl -> ActiveMessageC;

}