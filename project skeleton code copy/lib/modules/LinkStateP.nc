#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module LinkStateP{ 
    provides interface LinkState; 

    uses interface Flooding;
    uses interface NeighborDiscovery;
    uses interface Timer<TMilli> as linkStateTimer;
}

implementation { 
    // Global Variables
    #define MAX_CACHE_SIZE 20 
    // #define INFINITY 255  // for Dijkstra
    #define NODES 20           // number of nodes in topology

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
        uint16_t num_neighbors;         // number of neighbors
        link_t links[NODES];            // array of links to neighbors connected to this node
    } topo_node_t;

    // adjacency list representation of the network topology
    topo_node_t network_topology[NODES];

    // === HELPER FUNCTIONS ===

    void sendLSA() { 

    }

    void dijkstra() { 

    }

    // === EVENTS AND COMMANDS BELOW ===

    // initialize LS
    command void LinkState.initialize() { 
        uint8_t i;
        dbg(ROUTING_CHANNEL, "LinkState: Initializing Link State Routing...\n");
        for (i = 0; i < NODES; i++) {
            routing_table[i].cost = INFINITY;                   // Initially unreachable
            routing_table[i].next_hop = AM_BROADCAST_ADDR;      // nonexistant next hop
            lsa_cache[i] = 0;
            network_topology[i].num_neighbors = 0;
        }

    }

    // handle incoming LSA packets
    event void Flooding.receive(pack* msg, uint16_t src) {

    }

    // get next hop
    command uint16_t LinkState.getNextHop(uint16_t dest) { 

        return 0;
    }

    // timer
    event void linkStateTimer.fired() { 

    }



    // What Link State Routing needs to do: 
    /** 
    - Timer will wait for before sending out initial LSA (Command)

    - Create and send LSA (Link State Advertisement) to all neighbors (Command)

    - Receive LSA from neighbors (Event)

    - Perform Dijkstra's algorithm to find shortest path (make its own function probably) (Command)

    - Need a way to detect that you know neighbors of all nodes in topology (Event)

    - Event that listens for changes in Neighbor Discovery  (Event)
        - Then Floods new LSA (Command)

    - Event that listens for IP packets  (Event)

    - Remove data when Link fails (Event)
    **/

}