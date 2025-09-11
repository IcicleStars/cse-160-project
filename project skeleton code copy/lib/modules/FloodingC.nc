#include "../../includes/am_types.h"

generic configuration Flooding(int channel){
   provides interface Flooding;
}

implementation{
   components new FloodingP(channel);
   Flooding = FloodingP;

   // AM_FLOODING = 10 based on am_types
   components new AMReceiverC(AM_FLOODING) as Receiver;     
   components new SimpleSendC(AM_FLOODING) as Sender;

   // Wire components
   FloodingP.SimpleSend -> Sender.SimpleSend;
   FloodingP.Receive -> Receiver.Receive;

   // Allows/wires use of timer
   components new TimerMilliC as myTimerC;
   FloodingP.Timer -> myTimerC;
   
   // Allows/wires Random
   components RandomC as random; 
    FloodingP.Random -> random;

   // allows/wires the floodingP module to use the LinkLayer module
   components new LinkLayerC() as LinkLayer; 
    FloodingP.LinkLayer -> LinkLayer;
   
}