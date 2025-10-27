#include "../../includes/LSA.h"

// also need to be able to ping neighbors
interface NeighborDiscovery{

   // Command to initiate neighbor discovery
   command void findNeighbors();

   // Command to print the list of discovered neighbors
   command void printNeighbors(); 

   // Command to get the neighbor table
   command NeighborEntry* getNeighbors(uint16_t* count);

   // Event signaled when the neighbor table is updated
   event void neighborTableUpdated();
}