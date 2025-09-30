#include "../../includes/am_types.h"

configuration FloodingC{
   provides interface Flooding;
}

implementation{
   // AM_FLOODING = 10 based on am_types
   components FloodingP as FloodingP;
   Flooding = FloodingP;

   // Use LinkLayer
   components LinkLayerC;
   FloodingP.LinkLayer -> LinkLayerC;

}