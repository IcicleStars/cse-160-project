#ifndef __LSA_H__
#define __LSA_H__

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