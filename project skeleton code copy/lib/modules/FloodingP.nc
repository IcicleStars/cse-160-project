/** 
Notes:
to broadcast to all nodes, use AM_BROADCAST_ADDR

**/

generic module FloodingP{ 
    provides interface Flooding; 
    uses { 
        interface SimpleSend;
        interface Receive;
        interface Timer<TMilli>; 
        interface Random;
    }
}

implementation { 

    typedef struct { 
        am_addr_t source;       // Flooding Origin Address
        uint16_t seq_num;       // Sequence Number
        uint8_t ttl;            // time to live

        uint8_t payload[0];     // end header with zero length array to access payload
    } 



}