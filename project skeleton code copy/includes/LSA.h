#ifndef __LSA_H__
#define __LSA_H__



// This is required so LinkStateP.nc knows the structure of data
// returned by the NeighborDiscovery.getNeighbors() command.
typedef struct { 
    uint16_t node_id;
    uint8_t link_quality;   
    bool is_active;
    uint16_t last_seq_num_heard;
    uint32_t total_packets_received;
    uint32_t total_packets_expected;
    uint8_t consecutive_misses;
} NeighborEntry;

// define lsa neighbor tuple
typedef nx_struct LSANeighbor { 
    nx_uint16_t id;           // neighbor id
    nx_uint16_t cost;         
} LSANeighbor;


// link state advertisement structure
typedef nx_struct LSAHdr { 
    // nx_uint16_t src;             // source of lsa 
    nx_uint16_t seq;                // sequence number
    nx_uint8_t neighborCount;       // number of neighbors
    LSANeighbor neighbors[0];       // array of neighbors

    nx_uint8_t payload[0];     // end header with zero length array to access payload
} LSAHdr;

#endif