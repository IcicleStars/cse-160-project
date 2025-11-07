#ifndef __TCP_H__
#define __TCP_H__

#include "socket.h" 

// flags
enum { 
    TCP_SYN = 1 << 0,
    TCP_ACK = 1 << 1,
    TCP_FIN = 1 << 2,
};

// struct
typedef nx_struct tcp_header{ 
    nx_uint8_t src_port;
    nx_uint8_t dest_port;
    nx_uint8_t seq_num;
    nx_uint8_t ack_num;
    nx_uint8_t flags;
    nx_uint8_t window; 
    nx_uint8_t payload[SOCKET_BUFFER_SIZE];
} tcp_header;

#endif 