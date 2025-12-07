#ifndef __SOCKET_H__
#define __SOCKET_H__

#define MAX_USERNAME_LEN 16



enum{
    MAX_NUM_OF_SOCKETS = 10,
    ROOT_SOCKET_ADDR = 255,
    ROOT_SOCKET_PORT = 255,
    SOCKET_BUFFER_SIZE = 128,
    TCP_TIMER_ID = 0
};

enum socket_state{
    CLOSED,
    LISTEN,
    ESTABLISHED,
    SYN_SENT,
    SYN_RCVD,

    // teardown states
    FIN_WAIT_1,
    FIN_WAIT_2,
    CLOSE_WAIT,
    LAST_ACK,

    CLOSING,
    TIME_WAIT
};


typedef nx_uint8_t nx_socket_port_t;
typedef uint8_t socket_port_t;
// File descripter id. Each id is associated with a socket_store_t
typedef uint8_t socket_t;

// socket_addr_t is a simplified version of an IP connection.
typedef nx_struct socket_addr_t{
    nx_socket_port_t port;
    nx_uint16_t addr;
}socket_addr_t;

// user list struct 
typedef struct {
    uint8_t used;
    uint16_t addr;      // Client Node ID (e.g., 2, 3, etc.)
    uint8_t port;       // Client Port (The clientPort from the hello command)
    socket_t fd;        // The accepted socket descriptor (for sending data)
    char username[MAX_USERNAME_LEN];
} user_entry_t;


// State of a socket. 
typedef struct socket_store_t{
    uint8_t flag;
    enum socket_state state;
    socket_port_t src;
    socket_addr_t dest;

    // This is the sender portion.
    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint16_t lastWritten;
    uint16_t lastAck;
    uint16_t lastSent;
    uint8_t last_sent_len;

    // This is the receiver portion
    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint16_t lastRead;
    uint16_t lastRcvd;
    uint16_t nextExpected;

    uint16_t RTT;
    uint8_t effectiveWindow;

    // CONGESTION CONTROL (command window,  slow start threshhold, duplicate ack counter)
    uint16_t cwnd; 
    uint16_t ssthresh; 
    uint8_t dupAckCount; 



    // track current congestion phase
    enum { 
        SLOW_START,
        CONG_AVOIDANCE
    } congState;
    

}socket_store_t;



#endif
