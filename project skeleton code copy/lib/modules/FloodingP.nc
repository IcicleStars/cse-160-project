/** 
Notes:
to broadcast to all nodes, use AM_BROADCAST_ADDR

**/

#include "../../includes/Flooding.h"

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

    // ICE NOTES FOR MORNING: 
    // - make sure interface uses are correct
    // - Add error fommand to interface 
    // - dont kill yourself
    // - add accessibility to structure in Flooding.h 
    // - worry about logic once things are created and actually wired/connected stop worrying about that please

}