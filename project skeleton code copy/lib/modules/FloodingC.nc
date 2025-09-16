#include "../../includes/am_types.h"

configuration FloodingC{
   provides interface Flooding;
}

implementation{
   // AM_FLOODING = 10 based on am_types
   components FloodingP as FloodingP;
   Flooding = FloodingP;

   // Create Timer
   components new TimerMilliC() as FloodingTimer;
   FloodingP.Timer -> FloodingTimer.Timer;

   // Random number generator
   components RandomC as Random;
   FloodingP.Random -> Random;

   // Use LinkLayer
   components LinkLayerC;
   FloodingP.LinkLayer -> LinkLayerC;

}