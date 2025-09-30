#ifndef __FLOODING_HDR_H__
#define __FLOODING_HDR_H__

typedef nx_struct FloodingHdr{ 
    nx_uint16_t source;       // Flooding Origin Address
    nx_uint16_t seq_num;       // Sequence Number
    nx_uint8_t ttl;            // time to live

    nx_uint8_t payload[0];     // end header with zero length array to access payload
} FloodingHdr;

#endif