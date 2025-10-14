#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include <limits.h>

module LinkStateP{ 
    provides interface LinkState; 

    uses interface Flooding;
    uses interface NeighborDiscovery;
}

implementation { 
    // Global Variables
    #define MAX_CACHE_SIZE 20; 
    #define INFINITY UINT_MAX;  // for Dijkstra
    #define NODES 20;           // number of nodes in topology

    // === ROUTING TABLE ===
    typedef struct {
        uint16_t dest;             // destination address
        uint16_t next_hop;         // next hop address
        uint8_t cost;               // cost to reach destination
    } routing_entry_t;              // define an entry in the routing table

    routing_entry_t routing_table[MAX_CACHE_SIZE]; // holds the routing table entries

    // === LSA CACHE ===
    uint16_t lsa_cache[MAX_CACHE_SIZE]; // holds LATEST sequence num for each node

    // === NETWORK TOPOLOGY GRAPH === 
    typedef struct { 
        uint16_t neighbor;  // neighbor address
        uint16_t cost;
    } link_t; 

    typedef struct { 
        uint16_t node;         // node address
        link_t links[NODES];    // array of links to neighbors connected to this node
    } topo_node_t;

    // adjacency list representation of the network topology
    topo_node_t network_topology[NODES];


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