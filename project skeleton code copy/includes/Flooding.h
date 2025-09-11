#ifndef __FLOODING_H__
#define __FLOODING_H__

typedef struct FloodingHeader{ 
    am_addr_t source;       // Flooding Origin Address
    uint16_t seq_num;       // Sequence Number
    uint8_t ttl;            // time to live

    uint8_t payload[0];     // end header with zero length array to access payload
} FloodingHeader;

#endif