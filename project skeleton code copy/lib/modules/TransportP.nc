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
    // buffer for outgoing packets
    pack sendBuffer;

    // get first available socket
    socket_t get_free_socket() { 
        uint8_t i;

        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++) { 
            if(sockets[i].state == CLOSED && sockets[i].src == 0) { 
                return (socket_t)(i + 1);
            }
        }
        return 0;
    }

    // helper functions
    // creates tcp packet
    error_t send_tcp_packet(uint8_t index, uint8_t flags, uint8_t* payload, uint8_t payload_len) { 
        
        // initialize
        socket_store_t* s = &sockets[index];
        tcp_header* t_hdr = (tcp_header*)sendBuffer.payload;
        error_t result;

        // fill header
        t_hdr->src_port = s->src;
        t_hdr->dest_port = s->dest.port;
        t_hdr->flags = flags;
        t_hdr->seq_num = s->lastSent;
        t_hdr->ack_num = s->nextExpected;
        t_hdr->window = 0;

        // fill IP header
        sendBuffer.src = TOS_NODE_ID;
        sendBuffer.dest = s->dest.addr;
        sendBuffer.protocol = PROTOCOL_TCP;
        sendBuffer.TTL = MAX_TTL;

        if (flags & TCP_SYN) { 
            dbg(TRANSPORT_CHANNEL, "send_tcp_packet: SENDING SYN to %u\n", s->dest.addr);
        }
        if (flags & TCP_FIN) { 
            dbg(TRANSPORT_CHANNEL, "send_tcp_packet: SENDING FIN to %u\n", s->dest.addr);
        }

        dbg(TRANSPORT_CHANNEL, "Calling IP.send() to %u\n", s->dest.addr);
        result = call IP.send(&sendBuffer, s->dest.addr);

        if ( result != SUCCESS ) { 
            dbg(TRANSPORT_CHANNEL, "IP Send FAILED!!!");
        } else { 
            dbg(TRANSPORT_CHANNEL, "IP SEND SUCCEED");
        }

        // send the packet
        return;

    }

    // find socket for packet
    uint8_t find_socket_index(uint16_t src_addr, uint8_t src_port, uint8_t dest_port) { 

        uint8_t i;

        // find match 
        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++) { 
            if(sockets[i].state != CLOSED && 
            sockets[i].dest.addr == src_addr && 
            sockets[i].dest.port == src_port && 
            sockets[i].src == dest_port) { 
                return i;
            }
        }

        // find listening socket if no established connections are available
        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) { 
            if (sockets[i].state == LISTEN && sockets[i].src == dest_port) { 
                return i;
            }
        }

        // otherwise no match
        return MAX_NUM_OF_SOCKETS;

    }

    // Actual Implementation
    // get socket if one is available
    command socket_t Transport.socket() { 
        socket_t fd = get_free_socket(); 

        if(fd > 0) { 
            // initialize index
            uint8_t index = fd - 1; 

            // clear data from socket struct
            memset(&sockets[index], 0, sizeof(socket_store_t));
            sockets[index].state = CLOSED;

            // initialize values for stop and wait
            sockets[index].lastAck = 0;
            sockets[index].lastSent = 0;

        }

        return fd;
    }

    // bind a socket with an address 
    command error_t Transport.bind(socket_t fd, socket_addr_t *address) { 
        uint8_t index; 

        // must be valid file descriptor
        if (fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return FAIL;
        }

        index = fd - 1;

        // socket must be closed
        if  (sockets[index].state != CLOSED) { 
            return FAIL;
        }

        // bind the socket with the port
        sockets[index].src = address->port;
        return SUCCESS;
    }

    // check to see if there are socket connections to connect to and connect to it if there is one
    command socket_t Transport.accept(socket_t fd) { 
        uint8_t listen_index;
        uint8_t i;

        if (fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return 0;
        }

        listen_index = fd - 1;

        // ensure the fd we're accepting on is actually a listening socket
        if (sockets[listen_index].state != LISTEN) { 
            return 0;
        }

        // find new socket for port 
        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) { 
            if (i == listen_index) { 
                // reject
                continue;
            }

            // check for available ESTABLISHED socket 
            if (sockets[i].src == sockets[listen_index].src && sockets[i].state == ESTABLISHED && sockets[i].flag == 0) { 
                sockets[i].flag = 1; 
                return (socket_t)(i + 1); // reutnrs new FD
            }
        }

        return 0; // no new connection
    }

    // write to the socket from a buffer.
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) { 
        uint8_t index;
        socket_store_t* s;
        // 
        if (fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return 0;
        }

        index = fd - 1;
        s = &sockets[index];

        // check for established socket
        if (s->state != ESTABLISHED) { 
            return 0;
        }

        // stop and wait
        if(s->lastSent > s->lastAck) { 
            dbg(TRANSPORT_CHANNEL, "Transport: Waiting for ACK\n");
            return 0;
        }

        // truncate large data
        if (bufflen > SOCKET_BUFFER_SIZE) { 
            bufflen = SOCKET_BUFFER_SIZE;
        }

        // incremenet seq no.
        s->lastSent = s->lastSent + 1;

        // send data packet
        if(send_tcp_packet(index, TCP_ACK, buff, bufflen) == SUCCESS) { 
            return bufflen;
        }
        else { 
            // undo increment seq. no because of failure
            s->lastSent = s->lastSent - 1;
        }
        return 0;
    }

    // pass the packet to handle internally
    command error_t Transport.receive(pack* package) { 
        return SUCCESS;

    }

    // read from the socket and write this data to the buffer.
    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) { 

        // 

        return 0;
    }

    // attempts a connection to an address
    command error_t Transport.connect(socket_t fd, socket_addr_t *dest) {
        uint8_t index;
        error_t result;

        // must be valid fd
        if(fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return FAIL;
        }

        index = fd - 1;

        // bound/closed socket
        if (sockets[index].state != CLOSED || sockets[index].src == 0) { 
            dbg(TRANSPORT_CHANNEL, "connect failed, socket is neither closed nor bound\n");
            return FAIL;
        }

        // store dest infnormation
        sockets[index].dest.port = dest->port;
        sockets[index].dest.addr = dest->addr;

        sockets[index].state = SYN_SENT;

        // initial seq no.
        sockets[index].lastSent = 0;

        result = send_tcp_packet(index, TCP_SYN, NULL, 0);

        if (result != SUCCESS) { 
            dbg(TRANSPORT_CHANNEL, "connect FAILED and send packet failed");
            sockets[index].state = CLOSED;
        } else { 
            dbg(TRANSPORT_CHANNEL, "connect SUCCESS");
        }

        // sent SYN packet
        return result;

    }

    // closes the socket
    command error_t Transport.close(socket_t fd) { 
        uint8_t index;

        if(fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return FAIL;
        }

        index = fd - 1;

        if (sockets[index].state == ESTABLISHED) { 
            // active close
            if(send_tcp_packet(index, TCP_FIN, NULL, 0) == SUCCESS) { 
                sockets[index].state = FIN_WAIT_1;
                return SUCCESS;
            }

        }
        else if (sockets[index].state == CLOSE_WAIT) { 
            // passive close
            if(send_tcp_packet(index, TCP_FIN, NULL, 0) == SUCCESS) { 
                sockets[index].state = LAST_ACK;
                return SUCCESS;
            }

        }

        else if (sockets[index].state == SYN_SENT) { 
            sockets[index].state = CLOSED;
            memset(&sockets[index], 0, sizeof(socket_store_t));
            return SUCCESS;
        }

        // send fin packet


        return FAIL;
    }

    // forced close (optional?)
    command error_t Transport.release(socket_t fd) { 
        return SUCCESS;
    }

    // listen to the socket and wait for a connection
    command error_t Transport.listen(socket_t fd) { 
        uint8_t index;

        // must be valid file descriptor
        if (fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return FAIL;
        }

        index = fd - 1;

        // socket must be bound
        if (sockets[index].state != CLOSED || sockets[index].src == 0) { 
            return FAIL;
        }

        sockets[index].state = LISTEN;
        return SUCCESS;
    }

    // receive incoming tcp packets
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) { 
        pack* myMsg = (pack*)payload;
        tcp_header* t_hdr;
        uint8_t index;
        socket_store_t* s;
        uint8_t payload_len = 0; 

        // 
        if (myMsg-> protocol != PROTOCOL_TCP) { 
            return msg;
        }

        t_hdr = (tcp_header*)myMsg->payload;
        index = find_socket_index(myMsg->src, t_hdr->src_port, t_hdr->dest_port);

        // 
        if (index == MAX_NUM_OF_SOCKETS) { 
            return msg; // drop packet, no socket found
        }

        // matching socket
        s = &sockets[index];

        // state machine?
        switch(s->state) { 
            case LISTEN: 
            // handle new connection
            if (t_hdr->flags & TCP_SYN) { 
                socket_t new_fd = get_free_socket();
                if (new_fd > 0) { 

                    uint8_t new_index = new_fd - 1;
                    // initialize new socket!!!!!
                    memset(&sockets[new_index], 0, sizeof(socket_store_t));
                    sockets[new_index].src = s->src; // use listener's port
                    sockets[new_index].dest.port = t_hdr->src_port;
                    sockets[new_index].dest.addr = myMsg->src;
                    sockets[new_index].state = SYN_RCVD;
                    sockets[new_index].nextExpected = t_hdr->seq_num + 1;

                    // send syn and ack
                    send_tcp_packet(new_index, TCP_SYN | TCP_ACK, NULL, 0);

                }
            }
            break;

            // handle established connection
            case SYN_SENT:
                if (t_hdr->flags == (TCP_SYN | TCP_ACK)) { 
                    s->state = ESTABLISHED;
                    s->nextExpected = t_hdr->seq_num + 1;
                    s->lastAck = t_hdr->ack_num;

                    // send final ACK (3way handshake)
                    send_tcp_packet(index, TCP_ACK, NULL, 0);
                }
                break;
            
            // handle final ACK
            case SYN_RCVD:
                if (t_hdr->flags & TCP_ACK) { 
                    s->state = ESTABLISHED;
                    s->nextExpected = t_hdr->seq_num + 1;
                    s->lastAck = t_hdr->ack_num;
                }
                break;

            // handles incoming data
            case ESTABLISHED:
                if (t_hdr->flags & TCP_ACK) { 
                    // unblocj transport.write
                    if (t_hdr->ack_num > s->lastAck) { 
                        s->lastAck = t_hdr->ack_num;
                    }
                }

                // the actual process of handling data
                if (!(t_hdr->flags & TCP_SYN) && !(t_hdr->flags & TCP_FIN)) { 
                    // send ACK
                    s->nextExpected = t_hdr->seq_num + 1; 
                    send_tcp_packet(index, TCP_ACK, NULL, 0);
                }

                // handle teardown reqest
                if (t_hdr->flags & TCP_FIN) { 
                    s->state = CLOSE_WAIT; 
                    s->nextExpected = t_hdr->seq_num + 1; // ack fin

                    // send ack for fin
                    send_tcp_packet(index, TCP_ACK, NULL, 0);

                }
                break;

            // handles ack for fin
            case FIN_WAIT_1:
                if (t_hdr->flags & TCP_ACK) { 
                    s->state = FIN_WAIT_2;
                }
                break;

            // handles fin
            case FIN_WAIT_2: 
                if (t_hdr->flags & TCP_FIN) { 
                    s->state = CLOSED;
                    s->nextExpected = t_hdr->seq_num + 1;
                    send_tcp_packet(index, TCP_ACK, NULL, 0);

                    // clear socket
                    memset(s, 0, sizeof(socket_store_t));
                }
                break;

            // wait for other side to send FIN and call Transport.close()
            case CLOSE_WAIT: 
                // ignore incoming packets
                break;

            // waiting for final ack
            case LAST_ACK: 
                if(t_hdr->flags & TCP_ACK) { 
                    s->state = CLOSED;
                    // clear socket
                    memset(s, 0, sizeof(socket_store_t));
                }
                break;



        }

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