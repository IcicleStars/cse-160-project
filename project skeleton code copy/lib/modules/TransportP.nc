#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/TCP.h"
#include "../../includes/protocol.h"

module TransportP { 
    provides interface Transport;
    uses interface IP;
    uses interface Receive;
}

implementation { 
    // socket array
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];

    // get socket
    socket_t get_free_socket() { 
        uint8_t i;

        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++) { 
            if(sockets[i].state == CLOSED && sockets[i].src == 0) { 
                return (socket_t)(i + 1);
            }
        }
        return 0;
    }

    // Actual Implementation
    // get socket if one is available
    command socket_t Transport.socket() { 
        socket_t fd = get_free_socket(); 



        return fd;
    }

    // bind a socket with an address
    command error_t Transport.bind(socket_t fd, socket_addr_t *address) { 



        return SUCCESS;
    }

    // check to see if there are socket connections to connect to and connect to it if there is one
    command socket_t Transport.accept(socket_t fd) { 
        return 0;
    }

    // write to the socket from a buffer.
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) { 
        return 0;
    }

    // pass the packet to handle internally
    command error_t Transport.receive(pack* package) { 
        return SUCCESS;

    }

    // read from the socket and write this data to the buffer.
    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) { 
        return 0;
    }

    // attempts a connection to an address
    command error_t Transport.connect(socket_t fd, socket_addr_t *dest) {
    return SUCCESS;
    
    
    }

    // closes the socket
    command error_t Transport.close(socket_t fd) { 
        return SUCCESS;
    }

    // forced close (optional?)
    command error_t Transport.release(socket_t fd) { 
        return SUCCESS;
    }

    // listen to the socket and wait for a connection
    command error_t Transport.listen(socket_t fd) { 



        return SUCCESS;
    }

    // receive incoming tcp packets
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) { 
        pack* myMsg = (pack*)payload;
        tcp_header* t_hdr;

        if (myMsg->protocol != PROTOCOL_TCP) { 
            return msg;
        }

        t_hdr = (tcp_header*)myMsg->payload;

        return msg;
    }

}


/* 

WHAT WE NEED TO DO FOR MID-REVIEW: 

-> Implement transport.socket: 
    - Find available socket slot
    - Initialize socket state 

-> Implement transport.bind: 
    - set socket source port 

-> Implement transport.listen: 
    - set socket state to LISTEN

-> Implement transport.connect: 
    - establish connection to destination

-> Implement transport.accept: 
    - check for established connections then return socked FD for that connection

-> Implement transport.write: 
    - send one data packet through socket if state is ESTABLISHED

-> Implement transport.close: 
    - send FIN flag and change state to FIN_WAIT_1

-> Implement transport.release: 
    - release socket resources

-> ACK stuff


*/