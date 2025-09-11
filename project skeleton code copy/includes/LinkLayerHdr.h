#ifndef __LINK_LAYER_HDR_H__
#define __LINK_LAYER_HDR_H__

typedef struct LinkLayerHdr{ 
    am_addr_t source;       // Source Address
    am_addr_t destination;  // Destination Address

    uint8_t payload[0];     // end header with zero length array to access payload
} LinkLayerHdr;

#endif