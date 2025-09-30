//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H


# include "protocol.h"
#include "channels.h"

enum {
    PACKET_HEADER_LENGTH = 8,
    PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
    MAX_TTL = 15,
    AM_PACK = 6,
    NEIGHBOR_DISCOVERY_PROTOCOL = 1,
    NEIGHBOR_DISCOVERY_REQUEST = 0,
    NEIGHBOR_DISCOVERY_REPLY = 1,
};


typedef nx_struct pack{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;	//Sequence Number
	nx_uint8_t TTL;		//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;


// Define the neighbor discovery header to be placed in the payload
typedef nx_struct nd_payload_t {
    nx_uint8_t messageType;
    nx_uint16_t sequence_num;
} nd_payload_t;


/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
void logPack(pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);

    if (input->protocol == NEIGHBOR_DISCOVERY_PROTOCOL) {
        // Cast the payload to the specific nd_payload_t struct
        nd_payload_t* nd_payload = (nd_payload_t*)input->payload;

        // Log the neighbor discovery payload details
        dbg(GENERAL_CHANNEL, "Neighbor Discovery Payload: Type: %hhu, Seq: %hhu\n",
        nd_payload->messageType, nd_payload->sequence_num);
    } else {
        // Log the payload as a string for other packet types
        dbg(GENERAL_CHANNEL, "Payload: %s\n", input->payload);
    }
}


#endif
