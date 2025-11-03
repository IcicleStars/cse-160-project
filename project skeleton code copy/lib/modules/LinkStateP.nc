#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/LSA.h"

module LinkStateP{ 
    provides interface LinkState; 

    uses interface Flooding;
    uses interface NeighborDiscovery;
    uses interface Timer<TMilli> as initialDijkstraTimer;
    uses interface Timer<TMilli> as lsaTimer;
}

implementation { 
    // Global Variables
    #define MAX_CACHE_SIZE 20 
    #define INF32 0xFFFFFFFF  // for Dijkstra
    #define INF8 0xFF
    #define NODES 20           // number of nodes in topology
    bool initialLSAPhase = TRUE;

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
    // checks if both nodes consider each other neighbors.
    bool isBidirectional(uint16_t node1, uint16_t node2) {
        uint8_t i;
        bool node2_sees_node1 = FALSE;

        // check bounds
        if (node1 >= NODES || node2 >= NODES) {
            dbg(ROUTING_CHANNEL,"isBidirectional: Invalid node ID (%hu or %hu)\n", node1, node2);
            return FALSE;
        }

        // check if node2's topology lists node1 as a neighbor
        for (i = 0; i < network_topology[node2].num_neighbors; i++) {
            if (network_topology[node2].links[i].neighbor == node1) {
                node2_sees_node1 = TRUE;
                // dbg(ROUTING_CHANNEL,"isBidirectional: Check PASSED for %hu -> %hu\n", node1, node2);
                break; // Found it
            }
        }

        // debugging output
        if (!node2_sees_node1) {
            //  dbg(ROUTING_CHANNEL,"isBidirectional: Check FAILED for %hu -> %hu (Node %hu doesn't see %hu)\n", node1, node2, node2, node1);
        }

        return node2_sees_node1; // Return TRUE only if node2 sees node1
    }

    void printRoutingTable() {
        uint8_t i;
        dbg(ROUTING_CHANNEL, "Node %hu Routing Table (Reachable):\n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, " Dest | Next Hop | Cost\n");
        for (i = 0; i < NODES; i++) {
            // Only print if there's a valid next hop
            if (routing_table[i].next_hop != AM_BROADCAST_ADDR && i != TOS_NODE_ID) {
                 dbg(ROUTING_CHANNEL, "   %2hhu |   %4hu | %3hhu\n",
                     i,
                     routing_table[i].next_hop,
                     routing_table[i].cost);
            }
        }
    }

    void printTopology() { 
        uint8_t i, j;
        dbg(ROUTING_CHANNEL, "Node %hu Network Topology:\n", TOS_NODE_ID);
        for (i = 0; i < NODES; i++) {
            dbg(ROUTING_CHANNEL, "\nNode %2hu: ", i);
            for (j = 0; j < network_topology[i].num_neighbors; j++) {
                dbg(ROUTING_CHANNEL, " -> (N:%2hu, C:%hu)",
                    network_topology[i].links[j].neighbor,
                    network_topology[i].links[j].cost);
            }
        }
    }

    // compute's Dijkstra's to calculate the shortest path to all nodes based on known data
    void dijkstra() { 
        uint32_t dist[NODES];
        uint16_t prev[NODES];
        bool visited[NODES];
        uint8_t i, u, j;

        // initialize distances and previous nodes
        for (i = 0; i < NODES; i++) { 
            dist[i] = INF32;
            prev[i] = AM_BROADCAST_ADDR;
            visited[i] = FALSE;
        }

        // set distance to self
        dist[TOS_NODE_ID] = 0;

        // finding Distances
        for(i = 0; i < NODES; i++) { 
            // find the unvisited node with the smallest distance
            uint32_t min_dist = INF32;
            uint16_t min_u = AM_BROADCAST_ADDR;
            
            for (u = 0; u < NODES; u++) { 
                if (!visited[u] && dist[u] < min_dist) { 
                    min_dist = dist[u];
                    min_u = u; 
                }
            }

            if (min_u == AM_BROADCAST_ADDR) { 
                // all remaining nodes are inaccessible
                break;
            }

            // mark the node as visited
            u = min_u;
            visited[u] = TRUE;

            // update distances to neighbors
            for (j = 0; j < network_topology[u].num_neighbors; j++) { 
                link_t link = network_topology[u].links[j];
                uint16_t v = link.neighbor;
                uint16_t cost = link.cost;

                // check for bidirectional link
                // check if neighbor has been visited
                if (!visited[v] && isBidirectional(u, v)) { 
                // if (!visited[v]) {
                    uint32_t alt = dist[u] + cost;
                    if (alt < dist[v]) { 
                        dist[v] = alt;
                        prev[v] = u;
                    }
                }
            }

            // if(TOS_NODE_ID == 1 || TOS_NODE_ID == 2 || TOS_NODE_ID == 3 || TOS_NODE_ID == 4 || TOS_NODE_ID == 5 || TOS_NODE_ID == 6 || TOS_NODE_ID == 7 || TOS_NODE_ID == 8 || TOS_NODE_ID == 9 || TOS_NODE_ID == 10) {
            //     printRoutingTable();
            // }
        }

        // update Routing Table
        for (i = 0; i < NODES; i++) { 
            if (i == TOS_NODE_ID) { 
                routing_table[i].cost = 0;
                routing_table[i].next_hop = TOS_NODE_ID;
            } else if (dist[i] != INF32) { 
                // trace to find next hop
                uint16_t curr_node = i; 

                // stop when node before current one is this node
                while (prev[curr_node] != TOS_NODE_ID) { 
                    curr_node = prev[curr_node];

                    if (curr_node == AM_BROADCAST_ADDR) { 
                        break;
                    }
                } 

                if(curr_node == AM_BROADCAST_ADDR) { 
                    // no valid path found
                    routing_table[i].cost = INF8;
                    routing_table[i].next_hop = AM_BROADCAST_ADDR;

                } else 
                {

                    // avoid cost overflow
                    if(dist[i] > 255) { 
                        routing_table[i].cost = INF8;
                    } else { 
                        routing_table[i].cost = (uint8_t)dist[i];
                    }
                    routing_table[i].next_hop = curr_node;

                }


            } else { 
                // unreachable
                routing_table[i].cost = INF8;
                routing_table[i].next_hop = AM_BROADCAST_ADDR;
            }
        }
    }

        // sends the Link State Advertisement to all its neighbors
        // IMPLEMENTATION OF "Then Floods new LSA"
    task void sendLSA() { 
        pack lsaPack;
        LSAHdr* lsaHdr;

        NeighborEntry* ndTable; 
        uint16_t ndCount;
        uint8_t i;
        LSANeighbor tempNeighbors[NODES]; 
        uint8_t activeNeighbors = 0;
        uint8_t total_payload_length;
        
        // get current neighbor table and count from Neighbor Discovery
        ndTable = call NeighborDiscovery.getNeighbors(&ndCount);
        
        // build the LSA Header
        memset(&lsaPack, 0, sizeof(pack));

        // the LSAHdr is placed inside the pack's payload
        lsaHdr = (LSAHdr*)lsaPack.payload;
        
        // populate neighbor data in a temporary local array first
        
        
        for (i = 0; i < ndCount; i++) {
            if (ndTable[i].is_active) {
                // Check to prevent overflow of the temporary array
                if (activeNeighbors < NODES) {
                    tempNeighbors[activeNeighbors].id = ndTable[i].node_id;
                    // cost calculation
                    if (ndTable[i].link_quality == 0) {
                        tempNeighbors[activeNeighbors].cost = INF8;
                    } else {
                        tempNeighbors[activeNeighbors].cost = 10000 / (ndTable[i].link_quality * ndTable[i].link_quality);
                    }

                    activeNeighbors++;
                }
            }
        }
        
        // Update the LSA Header with the new sequence number and active neighbor count
        lsaHdr->seq = ++lsa_cache[TOS_NODE_ID]; 
        lsaHdr->neighborCount = activeNeighbors;
        
        network_topology[TOS_NODE_ID].num_neighbors = activeNeighbors;
        for (i = 0; i < activeNeighbors; i++) { 
            network_topology[TOS_NODE_ID].links[i].neighbor = tempNeighbors[i].id;
            network_topology[TOS_NODE_ID].links[i].cost = tempNeighbors[i].cost;
        }
        
        // Copy the active neighbor data from the temporary array into the LSA's payload
        // The neighbors array starts right after the fixed part of LSAHdr
        memcpy(lsaHdr->neighbors, tempNeighbors, activeNeighbors * sizeof(LSANeighbor));
        
        // Set outer packet fields
        lsaPack.src = TOS_NODE_ID;
        lsaPack.dest = AM_BROADCAST_ADDR;
        lsaPack.protocol = PROTOCOL_LINKSTATE;
        lsaPack.TTL = MAX_TTL;

        // Calculate total payload length (Fixed Header + Neighbors Data)
        total_payload_length = sizeof(LSAHdr) + (activeNeighbors * sizeof(LSANeighbor));

        // Flood the LSA
        if (call Flooding.send(&lsaPack, AM_BROADCAST_ADDR, total_payload_length) != SUCCESS) { 
            // dbg(ROUTING_CHANNEL, "LinkState: Failed to send LSA flood packet.\n");
        } else {
            // dbg(ROUTING_CHANNEL, "LinkState: Sent new LSA with sequence %hu and %hu neighbors.\n", lsaHdr->seq, activeNeighbors);
        }

        // dijkstra();
    }


    // === EVENTS AND COMMANDS BELOW ===

    // initialize LS
    command void LinkState.initialize() { 
        uint8_t i;
        dbg(ROUTING_CHANNEL, "LinkState: Initializing Link State Routing \n");
        for (i = 0; i < NODES; i++) {
            routing_table[i].cost = INF8;                   // initially unreachable
            routing_table[i].next_hop = AM_BROADCAST_ADDR;      // nonexistant next hop
            lsa_cache[i] = 0;
            network_topology[i].num_neighbors = 0;
        }

        initialLSAPhase = TRUE;
        call initialDijkstraTimer.startOneShot(120000); // wait 120 seconds

        call lsaTimer.startPeriodic(101000); 

    }

    // handle incoming LSA packets
    event void Flooding.receive(pack* msg, uint16_t src) {

        // Process packet
        if(msg->protocol == PROTOCOL_LINKSTATE) { 
            // cast payload
            FloodingHdr* fh = (FloodingHdr*)msg->payload;
            LSAHdr* lsa = (LSAHdr*)fh->payload;

            // Check if LSA is newer
            if(lsa->seq > lsa_cache[src]) {  
                uint8_t i;
                uint8_t num_neigh;
                // dbg(ROUTING_CHANNEL, "LinkState: Received New LSA from %u (Seq %u)\n", src, lsa->seq);

                // Update Cache
                lsa_cache[src] = lsa->seq;

                // Update Topology
                num_neigh = lsa->neighborCount;
                if(num_neigh > NODES) { 
                    // dbg(ROUTING_CHANNEL, "LinkState: LSA from %u has too many neighbors (%u). Truncating.\n", src, num_neigh);
                    num_neigh = NODES;
                } // prevent buffer overflow


                network_topology[src].num_neighbors = num_neigh;


                for(i = 0; i < num_neigh; i++) { 
                    if(i < NODES) { 
                        network_topology[src].links[i].neighbor = lsa->neighbors[i].id;
                        network_topology[src].links[i].cost = lsa->neighbors[i].cost;
                    } else { 
                        // dbg(ROUTING_CHANNEL, "LinkState: Neighbor index %u out of bounds for LSA from %u. Skipping.\n", i, src);
                        break;
                    }
                }

                // clear stale links
                // dbg(ROUTING_CHANNEL, "Clearing stale links for node %u from index %hhu\n", src, num_neigh);
                for (i = num_neigh; i < NODES; i++) { // Start from num_neigh
                   network_topology[src].links[i].neighbor = AM_BROADCAST_ADDR; 
                   network_topology[src].links[i].cost = 0xFFFF; 
                }
                // Recalculate Routes
                if (!initialLSAPhase) {

                    dijkstra(); 
                }

            }

        }

    }

    // get next hop
    command uint16_t LinkState.getNextHop(uint16_t dest) { 
        if (dest < NODES) { 
            return routing_table[dest].next_hop;
        }

        return AM_BROADCAST_ADDR;
    }

    // timer
    event void initialDijkstraTimer.fired() { 
        if (initialLSAPhase) {
            initialLSAPhase = FALSE;
            // dbg(ROUTING_CHANNEL, "LinkState: Initial LSA phase over. Running first Dijkstra.\n");
            dijkstra();
        }
    }

    event void lsaTimer.fired() { 
        // dbg(ROUTING_CHANNEL, "LinkState: Periodic LSA timer fired. Posting LSA flood.\n");
        post sendLSA();
    }

    //- Create and send LSA (Link State Advertisement) to all neighbors (Command)
    //- Receive LSA from neighbors (Event)
    // IMPLEMENTATION OF "Event that listens for changes in Neighbor Discovery"
    event void NeighborDiscovery.neighborTableUpdated() { 
        // dbg(ROUTING_CHANNEL, "LinkState: Neighbor table updated. Posting LSA flood.\n");
        post sendLSA();
    }

    command void LinkState.printTable() {
        uint8_t i;
        dbg(ROUTING_CHANNEL, "Node %hu Routing Table (Reachable):\n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, " Dest | Next Hop | Cost\n");
        for (i = 0; i < NODES; i++) {
            // Only print if there's a valid next hop
            if (routing_table[i].next_hop != AM_BROADCAST_ADDR && i != TOS_NODE_ID) {
                 dbg(ROUTING_CHANNEL, "   %2hhu |   %4hu | %3hhu\n",
                     i,
                     routing_table[i].next_hop,
                     routing_table[i].cost);
            }
        }
    }

    command void LinkState.printLSA() { 
        printTopology();
        printRoutingTable();
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