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


}