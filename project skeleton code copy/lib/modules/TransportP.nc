#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/TCP.h"
#include "../../includes/protocol.h"

module TransportP { 
    provides interface Transport;
    uses interface IP;
    uses interface Receive;
    uses interface Timer<TMilli> as TCPTimer;
}

implementation { 
    // socket array
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];
    // buffer for outgoing packets
    pack sendBuffer;

    // timer ID and timeout value
    #define TIMEOUT_MS 2000UL // 2 seconds timeout
    #define MAX_TCP_DATA (PACKET_MAX_PAYLOAD_SIZE - sizeof(tcp_header))

    // prototypes
    void handle_timeout(uint8_t index);

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
        // t_hdr->window = SOCKET_BUFFER_SIZE - (s->lastRcvd - s->lastRead);
        
        if((flags & (TCP_SYN | TCP_FIN)) || payload_len == 0) { 
            t_hdr->window = SOCKET_BUFFER_SIZE - (s->lastRcvd - s->lastRead);
        }
        else { 
            t_hdr->window = payload_len;
        }

        // fill IP header
        sendBuffer.src = TOS_NODE_ID;
        sendBuffer.dest = s->dest.addr;
        sendBuffer.protocol = PROTOCOL_TCP;
        sendBuffer.TTL = MAX_TTL;

        if (payload != NULL && payload_len > 0) { 
            // copy data into sendBuffer payload
            memcpy(t_hdr + 1, payload, payload_len);
        }

        if (flags & TCP_SYN) { 
            // dbg(TRANSPORT_CHANNEL, "TransportP: SENDING SYN to %u\n", s->dest.addr);
        }
        if (flags & TCP_FIN) { 
            // dbg(TRANSPORT_CHANNEL, "TransportP: SENDING FIN to %u\n", s->dest.addr);
        }

        // dbg(TRANSPORT_CHANNEL, "TransportP: Calling IP.send() to %u\n", s->dest.addr);
        result = call IP.send(&sendBuffer, s->dest.addr);

        if ( result != SUCCESS ) { 
            // dbg(TRANSPORT_CHANNEL, "TransportP: IP Send FAILED!!!\n");
        } else { 
            // dbg(TRANSPORT_CHANNEL, "TransportP: IP SEND SUCCEEDED\n");
        }

        // send the packet
        return result;

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

    // sliding window sending logic
    void try_send_next(uint8_t index) { 
        uint16_t window_size;
        socket_store_t* s = &sockets[index];

        // 
        window_size = (s->cwnd < s->effectiveWindow) ? s->cwnd : s->effectiveWindow;
        if(s->effectiveWindow == 0) { 
            window_size = 0;
        }

        // keep sending as long as window has space with fixed window size
        while ((s->lastSent - s->lastAck) < window_size) { 

            // new data exists
            if (s->lastSent < s->lastWritten) { 
                uint16_t data_to_send;
                uint8_t payload_len;
                uint8_t payload[MAX_TCP_DATA];
                uint16_t i;

                data_to_send = s->lastWritten - s->lastSent;

                // limit payload sizes
                payload_len = MAX_TCP_DATA;

                if (data_to_send > payload_len) { 
                    data_to_send = payload_len;
                }

                dbg(TRANSPORT_CHANNEL, "TransportP: Window open; Sending bytes\n");

                for (i = 0; i < data_to_send; i++) { 
                    payload[i] = s->sendBuff[(s->lastSent + i) % SOCKET_BUFFER_SIZE];                
                }

                // send the packet
                if(send_tcp_packet(index, TCP_ACK, payload, data_to_send) == SUCCESS) { 

                    s->lastSent += data_to_send;

                    // start timer if it's not already running
                    if (call TCPTimer.isRunning() == FALSE) { 
                        call TCPTimer.startOneShot(TIMEOUT_MS);
                    }

                }
                else { 
                    // send failed
                    break;
                }

            } else { 
                // no data in send buffer
                break;
            }
        }

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

            sockets[index].effectiveWindow = 28;

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
        uint16_t space_left;
        socket_store_t* s;
        
        if (fd == 0 || fd > MAX_NUM_OF_SOCKETS) { return 0; } 

        index = fd - 1;
        s = &sockets[index];

        if (s->state != ESTABLISHED) { return 0; }

        space_left = (SOCKET_BUFFER_SIZE - 1) - (s->lastWritten - s->lastAck);

        if (bufflen > space_left) { 
            bufflen = space_left;
        }

        if (bufflen > 0) { 
            uint16_t i;
            for (i = 0; i < bufflen; i++) { 
                s->sendBuff[(s->lastWritten + i) % SOCKET_BUFFER_SIZE] = buff[i];
            }
            s->lastWritten += bufflen;
            try_send_next(index);
        }

        return bufflen;

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
            dbg(TRANSPORT_CHANNEL, "TransportP: connect failed, socket is neither closed nor bound\n");
            return FAIL;
        }

        // store dest infnormation
        sockets[index].dest.port = dest->port;
        sockets[index].dest.addr = dest->addr;

        sockets[index].state = SYN_SENT;

        // initial seq no.
        sockets[index].lastSent = 0;

        result = send_tcp_packet(index, TCP_SYN, NULL, 0);

        if (result == SUCCESS) { 
            // the SYN packet consumes one sequence number
            sockets[index].lastSent = 1;
            call TCPTimer.startOneShot(TIMEOUT_MS);
            dbg(TRANSPORT_CHANNEL, "TransportP: connect SUCCESS\n");
        } else { 
            dbg(TRANSPORT_CHANNEL, "TransportP: connect FAILED and send packet failed\n");
            sockets[index].state = CLOSED;
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

    // read from socket and write data to buffer
    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) { 
        uint8_t index;
        socket_store_t* s;
        uint16_t bytesAvailable;
        uint16_t bytesToCopy;
        uint16_t i;

        if (fd == 0 || fd > MAX_NUM_OF_SOCKETS) { 
            return 0;
        }
        index = fd - 1;
        s = &sockets[index];

        if (s->state != ESTABLISHED && s->state != CLOSE_WAIT) {return 0;}

        // how many bytes are in buffer
        bytesAvailable = s->lastRcvd - s->lastRead;

        if(bytesAvailable == 0) { 
            return 0;
        }

        bytesToCopy = (bytesAvailable < bufflen) ? bytesAvailable : bufflen;
        
        // copy data
        for(i = 0; i < bytesToCopy; i++) { 
            buff[i] = s->rcvdBuff[(s->lastRead + i) % SOCKET_BUFFER_SIZE];
        }

        // move read pointer 
        s->lastRead += bytesToCopy;

        dbg(TRANSPORT_CHANNEL, "TransportP: App read %hu bytes. Sending ACK for %hu\n", bytesToCopy, s->nextExpected);

        // send ACK with new advertised window
        send_tcp_packet(index, TCP_ACK, NULL, 0);

        return bytesToCopy;

    }

    command error_t Transport.receive(pack* package) { 
        return SUCCESS;
    }

    // receive incoming tcp packets
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) { 
        pack* myMsg = (pack*)payload;
        tcp_header* t_hdr;
        uint8_t index;
        socket_store_t* s;
        uint8_t payload_len; 

        // 
        if (myMsg-> protocol != PROTOCOL_TCP) { 
            return msg;
        }

        t_hdr = (tcp_header*)myMsg->payload;
        index = find_socket_index(myMsg->src, t_hdr->src_port, t_hdr->dest_port);
        // payload_len = t_hdr->window;
        // payload_len = len - (sizeof(pack) - PACKET_MAX_PAYLOAD_SIZE) - sizeof(tcp_header);

        // // if ( !(t_hdr->flags & (TCP_SYN | TCP_FIN )) ) { 
        // //     payload_len = t_hdr->window;
        // // } else { 
        // //     payload_len = 0;
        // // }
        // if( payload_len > 0 ) { 
        //     payload_len = t_hdr->window;
        // } else { 
        //     payload_len = 0;
        // }

        if (t_hdr->flags & (TCP_SYN | TCP_FIN)) { 
            payload_len = 0;

            s = &sockets[index];
            if(index != MAX_NUM_OF_SOCKETS) { 
                s->effectiveWindow = t_hdr->window;
            }
        }
        else if (t_hdr->flags == TCP_ACK) { 

            if (t_hdr->window <= MAX_TCP_DATA) { 
                payload_len = t_hdr->window;
            } else { 
                payload_len = 0;

                s = &sockets[index];
                if (index != MAX_NUM_OF_SOCKETS && s->state == ESTABLISHED) { 
                    s->effectiveWindow = t_hdr->window;
                }
            }

        } else { 
            payload_len = 0;
        }



        // 
        if (index == MAX_NUM_OF_SOCKETS) { 
            return msg; // drop packet, no socket found
        }

        // matching socket
        s = &sockets[index];

        // state machine
        switch(s->state) { 
            case LISTEN: 
            // handle and accept new connection
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

                    // store advertised window (flow control)
                    sockets[new_index].effectiveWindow = t_hdr->window;

                    // send syn and ack
                    send_tcp_packet(new_index, TCP_SYN | TCP_ACK, NULL, 0);

                    dbg(TRANSPORT_CHANNEL, "TransportP, New SYN received. Sending SYN-ACK\n");

                }
            }
            break;

            // completes client side of 3-way handshake
            case SYN_SENT:
                if (t_hdr->flags == (TCP_SYN | TCP_ACK)) { 
                    call TCPTimer.stop();
                    s->state = ESTABLISHED;
                    s->nextExpected = t_hdr->seq_num + 1;
                    s->lastAck = t_hdr->ack_num;
                    s->lastWritten = t_hdr->ack_num;
                    s->effectiveWindow = t_hdr->window;

                    // send final ACK (3way handshake)
                    send_tcp_packet(index, TCP_ACK, NULL, 0);

                    // CONGESTION CONTROL 

                    // set congestion state and events
                    s->cwnd = 64;
                    // s->ssthresh = 32;
                    // s->dupAckCount = 0;
                    // s->congState = SLOW_START;

                }
                break;
            
            // handle final ACK (server side of 3-way handshake)
            case SYN_RCVD:
                if (t_hdr->flags & TCP_ACK) { 
                    s->state = ESTABLISHED;
                    s->lastAck = t_hdr->ack_num;

                    // CONGESTION CONTROL 

                    // set congestion state and events
                    s->cwnd = 64;
                    // s->ssthresh = 32;
                    // s->dupAckCount = 0;
                    // s->congState = SLOW_START;
                } 
                else if (t_hdr->flags & TCP_SYN) { 
                    send_tcp_packet(index, TCP_SYN | TCP_ACK, NULL, 0);
                    dbg(TRANSPORT_CHANNEL, "TransportP: Dupe SYN received. Resnding SYN-ACK\n");
                }
                break;

            // handles incoming data
            case ESTABLISHED:
                if (t_hdr->flags & TCP_ACK) { 
                    // unblocj transport.write if received an ack
                    if (t_hdr->ack_num > s->lastAck) { 

                        dbg(TRANSPORT_CHANNEL, "TransportP: New Ack received: %hu\n", t_hdr->ack_num);

                        s->lastAck = t_hdr->ack_num;
                        s->dupAckCount = 0; 

                        s->effectiveWindow = t_hdr->window;

                        if (s->lastAck == s->lastSent) { 
                            call TCPTimer.stop();
                        } else { 
                            call TCPTimer.startOneShot(TIMEOUT_MS);
                        }

                        // window moved, try to send more
                        try_send_next(index);

                        // Duplicate Ack
                    } else if (t_hdr->ack_num == s->lastAck) { 
                        s->dupAckCount++;
                    }
                }

                // the actual process of handling data 
                if (!(t_hdr->flags & TCP_SYN) && !(t_hdr->flags & TCP_FIN) && (payload_len > 0)) { 
                    uint16_t seq_num = t_hdr->seq_num;

                    // expected packet
                    if (seq_num == s->nextExpected) { 
                        uint16_t i;
                        // copy data from packet into socket buffer 
                        // memcpy(&s->rcvdBuff[s->lastRcvd % SOCKET_BUFFER_SIZE], t_hdr + 1, payload_len);

                        // copy data into socket buffer circularly
                        for(i = 0; i < payload_len; i++) { 
                            s->rcvdBuff[(s->lastRcvd + i) % SOCKET_BUFFER_SIZE] = ((uint8_t*)(t_hdr+1))[i];
                        }
                        // update buffer tail pointer
                        // s->lastRcvd += payload_len;


                        

                        // update next expected
                        s->nextExpected += payload_len;

                        dbg(TRANSPORT_CHANNEL, "TransportP: Received %hu bytes. Next expected: %hu\n", payload_len, s->nextExpected);

                        // send ACK for data 
                        send_tcp_packet(index, TCP_ACK, NULL, 0);

                    } 
                    // out of order packets
                    else if (seq_num > s->nextExpected) { 

                        // buffer packet 
                        memcpy(&s->rcvdBuff[seq_num % SOCKET_BUFFER_SIZE], t_hdr + 1, payload_len);

                        // send duplicate ACK for packet we're still waiting for
                        send_tcp_packet(index, TCP_ACK, NULL, 0);

                    }
                    else if (seq_num < s->nextExpected) { 

                        // old packet
                        send_tcp_packet(index, TCP_ACK, NULL, 0);

                    }

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
                    dbg(TRANSPORT_CHANNEL, "Received ACK, entering FIN_WAIT_2");
                    s->state = FIN_WAIT_2;
                }
                break;

            // handles fin for closing
            case FIN_WAIT_2: 
                if (t_hdr->flags & TCP_FIN) { 
                    dbg(TRANSPORT_CHANNEL, "Received FIN, sending ACK, closing\n");
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
                    dbg(TRANSPORT_CHANNEL, "closing\n");
                    s->state = CLOSED;
                    // clear socket
                    memset(s, 0, sizeof(socket_store_t));
                }
                break;



        }

        return msg;
    }


    event void TCPTimer.fired() {
        uint8_t i;
        // Iterate through all sockets
        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            socket_store_t* s = &sockets[i];

            // check for SYN_SENT timeout
            if (s->state == SYN_SENT) {
                dbg(TRANSPORT_CHANNEL, "TransportP: TIMEOUT detected for SYN_SENT socket %u\n", (unsigned int)(i + 1));
                call TCPTimer.stop();
                handle_timeout(i);
                break; // handle one timeout
            }
            // check for ESTABLISHED timeout
            else if (s->state == ESTABLISHED) {
                if (s->lastSent > s->lastAck) { // check for un-ACK'd data
                    dbg(TRANSPORT_CHANNEL, "TransportP: TIMEOUT detected for ESTABLISHED socket %u\n", (unsigned int)(i + 1));
                    call TCPTimer.stop();
                    handle_timeout(i);
                    break; // handle one timeout
                }
            }
        }
    // If no timer was started for this TCP_TIMER_ID, the fired event will typically not be called.
    // If a timer was started, we restart it if we are still waiting for an ACK.
    }

    void handle_timeout(uint8_t index) {
        socket_store_t* s = &sockets[index];

        if (s->state == SYN_SENT) {
            // Retransmit SYN packet (part of the 3-way handshake)
            dbg(TRANSPORT_CHANNEL, "TransportP: Retransmitting SYN for socket %u\n", (unsigned int)(index + 1));
            // Original SYN packet has no payload
            s->lastSent = 0;
            send_tcp_packet(index, TCP_SYN, NULL, 0); 
            s->lastSent = 1;
            call TCPTimer.startOneShot(TIMEOUT_MS); // Restart timer
        } 
        else if (s->state == ESTABLISHED) {
            
            dbg(TRANSPORT_CHANNEL, "TransportP: TIMEOUT. Going Back-N\n");

            // go back
            s->lastSent = s->lastAck;
            try_send_next(index);

        }
        // ... other states (e.g., FIN_WAIT_1) would need similar logic for FIN retransmission
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


// AFTER MID-REVIEW

-> Sliding Window
    (Sender Side)
    - Implement timers for timeouts 
    - resend packets upon timeout 
    (Receiver Side) (Me)
    - Implement buffer for potential out of order packets
    - handle incoming data packets in state machine 
    - make sure ACK sends data for last received and next expected 

// IF ENOUGH TIME: 

-> Congestion Control 
    - slow start + AIMD
    - congestion window 
    - duplicate ACK counter 
    - congestion states 
    - Congestion events
    

*/
