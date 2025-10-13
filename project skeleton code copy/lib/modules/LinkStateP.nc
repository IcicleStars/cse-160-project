#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module LinkStateP{ 
    provides interface LinkState; 

    uses interface Flooding;
    uses interface NeighborDiscovery;
}

implementation { 

    // What Link State Routing needs to do: 
    /** 

    - Create Routing Table (DS)
        - Should contain next hop for each node in topology based on Cost

    - Timer will wait for before sending out initial LSA (Command)

    - Create and send LSA (Link State Advertisement) to all neighbors (Command)

    - Receive LSA from neighbors (Event)

    - Perform Dijkstra's algorithm to find shortest path (make its own function probably) (Command)

    - LSA Cache (need one entry per node in topology) (DS)

    - Need a way to detect that you know neighbors of all nodes in topology (Event)

    - Event that listens for changes in Neighbor Discovery  (Event)
        - Then Floods new LSA (Command)

    - Event that listens for IP packets  (Event)

    - Remove data when Link fails (Event)

    **/

}