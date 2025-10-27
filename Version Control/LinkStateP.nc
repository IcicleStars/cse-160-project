#include "../../includes/am_types.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/LSA.h" 


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

    // IMPLEMENTATION OF "Then Floods new LSA"
    task void sendLSA() { 
        pack lsaPack;
        LSAHdr* lsaHdr;
        // NeighborEntry is from the NeighborDiscovery interface, used to store link data
        NeighborEntry* ndTable; 
        uint16_t ndCount;
        uint8_t i;
        LSANeighbor tempNeighbors[NODES]; 
        uint8_t activeNeighbors = 0;
        uint8_t total_payload_length;
        
        // 1. Get current neighbor table and count from Neighbor Discovery
        ndTable = call NeighborDiscovery.getNeighbors(&ndCount);
        
        // 2. Build the LSA Header
        memset(&lsaPack, 0, sizeof(pack));

        // The LSAHdr is placed inside the pack's payload
        lsaHdr = (LSAHdr*)lsaPack.payload;
        
        // 3. Populate neighbor data in a temporary local array first
        
        
        for (i = 0; i < ndCount; i++) {
            if (ndTable[i].is_active) {
                // Check to prevent overflow of the temporary array
                if (activeNeighbors < NODES) {
                    tempNeighbors[activeNeighbors].id = ndTable[i].node_id;
                    // Cost calculation: assuming higher LQ means lower cost. 
                    // A common simple cost is 1 for a direct link.
                    // Using 1 for simplicity here, but a complex metric (e.g., 101 - LQ) could be used.
                    tempNeighbors[activeNeighbors].cost = 1; 
                    activeNeighbors++;
                }
            }
        }
        
        // 4. Update the LSA Header with the new sequence number and active neighbor count
        lsaHdr->seq = ++lsa_cache[TOS_NODE_ID]; 
        lsaHdr->neighborCount = activeNeighbors;
        
        
        // 5. Copy the active neighbor data from the temporary array into the LSA's payload
        // The neighbors array starts right after the fixed part of LSAHdr
        memcpy(lsaHdr->neighbors, tempNeighbors, activeNeighbors * sizeof(LSANeighbor));
        
        // 6. Set outer packet fields
        lsaPack.src = TOS_NODE_ID;
        lsaPack.dest = AM_BROADCAST_ADDR;
        lsaPack.protocol = PROTOCOL_LINKSTATE;
        lsaPack.TTL = MAX_TTL;

        // 7. Calculate total payload length (Fixed Header + Neighbors Data)
        total_payload_length = sizeof(LSAHdr) + (activeNeighbors * sizeof(LSANeighbor));

        // 8. Flood the LSA
        if (call Flooding.send(&lsaPack, AM_BROADCAST_ADDR, total_payload_length) != SUCCESS) { 
            dbg(ROUTING_CHANNEL, "LinkState: Failed to send LSA flood packet.\n");
        } else {
            dbg(ROUTING_CHANNEL, "LinkState: Sent new LSA with sequence %hu and %hu neighbors.\n", lsaHdr->seq, activeNeighbors);
        }
    }

    void dijkstra() { 

    }

    // === EVENTS AND COMMANDS BELOW ===

    // Define lsa_seq_num as a task so it can be posted from the event handler
    task void sendLSA();    


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

    // Add the command to clean up local tables when a link is confirmed dead
    command void LinkState.removeLink(uint16_t neighborId) {
        uint8_t i, j;
        
        // 1. Remove the link from the local topology graph (network_topology[TOS_NODE_ID])
        if (TOS_NODE_ID < NODES) {
            topo_node_t* localNode = &network_topology[TOS_NODE_ID];
            
            for (i = 0; i < localNode->num_neighbors; i++) {
                if (localNode->links[i].neighbor == neighborId) {
                    // Found the link to remove. Shift the array.
                    for (j = i; j < localNode->num_neighbors - 1; j++) {
                        localNode->links[j] = localNode->links[j + 1];
                    }
                    localNode->num_neighbors--;
                    dbg(ROUTING_CHANNEL, "LinkState: Removed link to neighbor %hu from local topology.\n", neighborId);
                    break;
                }
            }
        }
        
        // 2. Clear the node's entry from the routing table (if it was the next hop)
        for (i = 0; i < MAX_CACHE_SIZE; i++) {
            // If the removed neighbor was the next hop for any destination, invalidate the route.
            if (routing_table[i].next_hop == neighborId) {
                routing_table[i].next_hop = AM_BROADCAST_ADDR;
                routing_table[i].cost = INFINITY;
            }
        }

        // NOTE: This function does NOT perform Dijkstra's or send an LSA.
        // The link state update and LSA send will be handled by the existing
        // NeighborDiscovery.neighborTableUpdated event.
}   
    
    //- Create and send LSA (Link State Advertisement) to all neighbors (Command)
    //- Receive LSA from neighbors (Event)
    // IMPLEMENTATION OF "Event that listens for changes in Neighbor Discovery"
    event void NeighborDiscovery.neighborTableUpdated() { 
        dbg(ROUTING_CHANNEL, "LinkState: Neighbor table updated. Posting LSA flood.\n");
        post sendLSA();
    }


    // What Link State Routing needs to do: 
    /** 
    - Timer will wait for before sending out initial LSA (Command)

    - Create and send LSA (Link State Advertisement) to all neighbors (Command)

    - Receive LSA from neighbors (Event)

    - Perform Dijkstra's algorithm to find shortest path (make its own function probably) (Command)

    - Need a way to detect that you know neighbors of all nodes in topology (Event)

    Event that listens for changes in Neighbor Discovery  (Event)
        Then Floods new LSA (Command)
        


    - Event that listens for IP packets  (Event)

    - Remove data when Link fails (Event)
    **/

}