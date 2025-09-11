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

generic module NeighborDiscoveryP(){
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as neighborTimer;
    uses interface Random;
}

implementation{
    command void NeighborDiscovery.findNeighbors(){
        // need timer for neighbor discovery to prevent packet congestion
        // all 19 nodes will start at different times
        call neighborTimer.startOneShot(100+ (call Random.rand16() %300)); 
    }

    task void search(){
        // logic: search for the neighbors send the message, if somone responds, save its id inside table
        // find a good place to put this message because we need to find nodes periodically
        call neighborTimer.startPeriodic(100+ (call Random.rand16() %300)); 

    }

    // Timer fired event for neighbor discovery
    event void sendTimer.fired(){
      post search();
   }

    // print the list of active neighbors
    command void NeighborDiscovery.printNeighbors(){
    }

   
}
