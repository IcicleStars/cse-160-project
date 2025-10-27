/**
 * ANDES Lab - University of California, Merced
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#include "../../includes/LSA.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as neighborTimer;
    uses interface Timer<TMilli> as qualityCheckTimer;
    uses interface Random;
    uses interface AMSend; // Use the standard TinyOS send interface
    uses interface Receive; // Use the standard TinyOS receive interface
    uses interface Packet;
    uses interface Boot; 

}

implementation{
    // define macros
    # define MAX_NEIGHBORS 10

    message_t send_buffer;
    static nx_uint16_t next_seq;
    bool timersStarted;

    // hold reply destination
    uint16_t reply_dest;

    // This struct defines the entry for a neighbor
    // typedef struct { 
    //     uint16_t node_id;     
    //     uint8_t link_quality;   
    //     bool is_active;

    //     uint16_t last_seq_num_heard;
    //     uint32_t total_packets_received;
    //     uint32_t total_packets_expected;
    //     uint8_t consecutive_misses;

    // } NeighborEntry;
    // creates neighbor table
    NeighborEntry neighbor_table[MAX_NEIGHBORS];

        event void Boot.booted() {
        // Initialize the sequence number based on the node's ID to ensure it is unique
        // next_seq = (uint16_t)TOS_NODE_ID * 1000;
        // dbg(NEIGHBOR_CHANNEL, "Upon booting, next_seq:%hu", next_seq);
        // actually call Neighbor Discovery
        // call NeighborDiscovery.findNeighbors();
        call neighborTimer.startOneShot(100 + (call Random.rand16() % 300));
        call qualityCheckTimer.startPeriodic(30000);
    }
   


    // core logic for sending the discovery packet
    task void search() {
        // Declare all variables at the beginning of the function scope
        pack* packet_payload;
        error_t result;
        nd_payload_t* nd_payload;
        

        // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: search task started.\n");

        

        // Get the payload pointer from the static message buffer
        packet_payload = (pack*)call Packet.getPayload(&send_buffer, sizeof(pack));
        
        

        if (packet_payload != NULL) {
            // Populate the packet's fields
            packet_payload->dest = AM_BROADCAST_ADDR;
            packet_payload->src = TOS_NODE_ID;
            packet_payload->protocol = NEIGHBOR_DISCOVERY_PROTOCOL;
            packet_payload->seq = next_seq++; 

            // Add the neighbor discovery specific payload
            // This is a crucial step to distinguish the type of packet
            nd_payload = (nd_payload_t*)packet_payload->payload;

            nd_payload->messageType = NEIGHBOR_DISCOVERY_REQUEST;
            nd_payload->sequence_num = packet_payload->seq; // Use the same sequence number

            logPack(packet_payload);
            // print payload details to dbg
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Package Payload: ND_REQUEST, sequence_num=%u\n", nd_payload->sequence_num);
            // Send the packet over the air
            result = call AMSend.send(AM_BROADCAST_ADDR, &send_buffer, sizeof(pack));
            
            if (result == SUCCESS) {
                // Packet sent successfully
                // You can add debug statements here to confirm
                // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Packet successfully sent.\n");

            }else {
                // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Failed to send packet with error: %d\n", result);
                }
        }   
    
      
    }

        command void NeighborDiscovery.findNeighbors(){
        // Start the neighbor discovery process by posting the search task
        
        // need timer for neighbor discovery to prevent packet congestion
        // all 19 nodes will start at different times
        // call neighborTimer.startOneShot(100+ (call Random.rand16() %300)); 
        if(!timersStarted) { 
            dbg(NEIGHBOR_CHANNEL, "NeighborDiscovery: Starting timers for the first time.\n");

            // discovery broadcast
            call neighborTimer.startOneShot(100 + (call Random.rand16() %300));

            // quality check
            call qualityCheckTimer.startPeriodic(30000);

        } else { 
            call neighborTimer.startOneShot(100 + (call Random.rand16() %300));
        }

    }


    event void AMSend.sendDone(message_t* msg, error_t err){
        // Set a new timer to send the next discovery packet
        // This creates the periodic behavior
        if(err == SUCCESS){
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Packet successfully sent. Restarting timer.\n");
            call neighborTimer.startOneShot(30000);
            call qualityCheckTimer.startPeriodic(30000);
        }else {
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Failed to send packet with error: %d\n", err);
        }
        
        
    }
    


    // Timer fired event for neighbor discovery
    event void neighborTimer.fired(){
        post search();
    }

    // quality timer
    event void qualityCheckTimer.fired() {
        int i;
        // dbg(NEIGHBOR_CHANNEL, "Quality check timer fired.\n");
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            // Only check active neighbors
            if (neighbor_table[i].is_active) {
                // increment consecutive misses. Will be set back to zero if packet is sent.
                neighbor_table[i].consecutive_misses++;
                // Check if link quality is below the threshold OR has too many consecutive misses
                if (neighbor_table[i].link_quality <= 25 || neighbor_table[i].consecutive_misses > 8) {
                    // Drop the neighbor by resetting the entry
                    dbg(NEIGHBOR_CHANNEL, "Neighbor %hu dropped due to low link quality or consecutive misses (%hu%% LQ, %u consecutive misses)\n", neighbor_table[i].node_id, neighbor_table[i].link_quality, neighbor_table[i].consecutive_misses);
                    neighbor_table[i].is_active = FALSE;
                    neighbor_table[i].link_quality = 0;
                    neighbor_table[i].node_id = 0;
                    neighbor_table[i].total_packets_expected = 0;
                    neighbor_table[i].consecutive_misses = 0;
                    neighbor_table[i].total_packets_received = 0;
                    neighbor_table[i].last_seq_num_heard = 0;

                    signal NeighborDiscovery.neighborTableUpdated();

                } else { 
                    // dbg(NEIGHBOR_CHANNEL, "Neighbor %hu still has good link quality and will not be dropped\n", neighbor_table[i].node_id);
                }
            }
        }
    }

        command NeighborEntry* NeighborDiscovery.getNeighbors(uint16_t* count) {
        // Return the actual size of the table, as defined by the macro.
        *count = MAX_NEIGHBORS; 
        
        // Return a pointer to the start of the table.
        // The calling module (LinkStateP) will need to filter for active neighbors.
        return neighbor_table; 
    }

    // TASK SENDS REPLY PACKET FOR RECEIVE
    task void sendReply() { 
        // Initialize variables
        pack* packet_payload;
        nd_payload_t* nd_payload;
        error_t result; 


        // print reply message
        // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Replying to node %u\n", reply_dest);

        // get payload pointer
        packet_payload = (pack*)call Packet.getPayload(&send_buffer, sizeof(pack));

        // Check if payload actually exists
        if(packet_payload == NULL) { 
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Failed to get payload for reply\n");
            return;
        }    

        // Populate packet fields
        packet_payload->dest = reply_dest; // sends to specific node requested
        packet_payload->src = TOS_NODE_ID;
        packet_payload->protocol = NEIGHBOR_DISCOVERY_PROTOCOL;
        packet_payload->seq = next_seq++;

        // Get the neighbor discovery payload
        nd_payload = (nd_payload_t*)packet_payload->payload;

        // set the message type to reply
        nd_payload->messageType = NEIGHBOR_DISCOVERY_REPLY;
        nd_payload->sequence_num = packet_payload->seq;

        // Send the reply packet directly to the destination
        result = call AMSend.send(reply_dest, &send_buffer, sizeof(pack));

        if (result != SUCCESS) { 
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: failed to send reply with error: %d\n", result);

        } else { 
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Reply packet send to %u\n", reply_dest);
        }

    }

    // process incoming packets from the radio
    // where we update ND table, calculate hwo many packets sent vs received, look at long ago ypuve received a packet packets received/packets sent
    event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
        // declarations
        pack* received_pack = (pack*)payload;
        nd_payload_t* nd_payload;
        bool neighbor_found = FALSE;
        uint16_t incoming_seq;
        uint16_t packets_missed;
        uint8_t i;
        uint8_t neighbor_i = MAX_NEIGHBORS;

        // dont do anything if protocol isnt for nd
        if (received_pack->protocol != NEIGHBOR_DISCOVERY_PROTOCOL) { 
            return buf;
        }

        // receive packet
        nd_payload = (nd_payload_t*)received_pack->payload;
        // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Received packet from %u\n", received_pack->src);

        // See if active neighbor already exists in table
        for(i = 0; i < MAX_NEIGHBORS; i++) { 
            if (neighbor_table[i].is_active && neighbor_table[i].node_id == received_pack->src) { 
                neighbor_i = i;
                // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Found existing neighbor %u\n", received_pack->src);
                break;
            }
        }

        // if neighbor doesn't yet actively exist in table
        if(neighbor_i == MAX_NEIGHBORS) { 
            for (i=0; i<MAX_NEIGHBORS; i++) { 
                if(!neighbor_table[i].is_active) { 
                    neighbor_i = i;

                    // create new neighbor entry 
                    neighbor_table[i].node_id = received_pack->src;
                    neighbor_table[i].is_active = TRUE;
                    neighbor_table[i].total_packets_received = 0;
                    neighbor_table[i].last_seq_num_heard = nd_payload->sequence_num - 1;

                    signal NeighborDiscovery.neighborTableUpdated();
                    dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Added new neighbor %u\n", received_pack->src);
                    break;
                }
            }
        }

        // Actions for when neighbor exists (whether newly or already)
        if (neighbor_i < MAX_NEIGHBORS) { 
            uint16_t last_seq;
            uint16_t current_seq;


            last_seq = neighbor_table[neighbor_i].last_seq_num_heard;
            current_seq = nd_payload->sequence_num;

            // update expected total for node
            if(neighbor_table[neighbor_i].total_packets_received == 0) { 
                // first packet
                neighbor_table[neighbor_i].total_packets_expected = 1;
            } else if (current_seq > last_seq) { 
                // update expected total
                neighbor_table[neighbor_i].total_packets_expected += (current_seq - last_seq);
            }

            // Update statistic variables
            neighbor_table[neighbor_i].consecutive_misses = 0;
            neighbor_table[neighbor_i].total_packets_received++;
            neighbor_table[neighbor_i].last_seq_num_heard = current_seq;

            // Calculate link quality
            neighbor_table[neighbor_i].link_quality = 
            (uint8_t)(((float)neighbor_table[neighbor_i].total_packets_received / (float)neighbor_table[neighbor_i].total_packets_expected) * 100);
            // dbg(NEIGHBOR_CHANNEL, "Link quality with neighbor %d: %d.\n", neighbor_table[neighbor_i].node_id, neighbor_table[neighbor_i].link_quality);

            // send reply if incoming message was a request
            if (nd_payload->messageType == NEIGHBOR_DISCOVERY_REQUEST) { 
                // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Received Request from %u, posting sendReply\n", received_pack->src);
                reply_dest = received_pack->src;
                post sendReply(); 
            } else if (nd_payload->messageType == NEIGHBOR_DISCOVERY_REPLY) {  // if incoming message was a request
                // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Received Reply from %u\n", received_pack->src);
            }
        }else { 
            // dbg(NEIGHBOR_CHANNEL, "NeighborDiscoveryP: Neighbor Table full\n");
        }

        return buf;
    }


// print the list of active neighbors
command void NeighborDiscovery.printNeighbors(){

    // declare variables
    uint8_t i;

    // print table
    dbg(GENERAL_CHANNEL, "Neighbor Table\n");
    for(i = 0; i < MAX_NEIGHBORS; i++) { 
        if (neighbor_table[i].is_active) { 
            dbg(GENERAL_CHANNEL, "Neighbor %u: ID=%u\n",i, neighbor_table[i].node_id );
        }
    }

    // will probably want to add neighbor table struct elements

}

   
}
