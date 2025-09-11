// also need to be able to ping neighbors
interface NeighborDiscovery{

   // Command to initiate neighbor discovery
   command void findNeighbors();

   // Command to print the list of discovered neighbors
   command void printNeighbors(); 
}