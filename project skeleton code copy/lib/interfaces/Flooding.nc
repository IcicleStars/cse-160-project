interface Flooding{
    // command error_t send(pack msg, uint16_t dest);
    
    command error_t send(pack *msg, uint16_t dest);
    event void receive(pack* msg, uint16_t src);
    // event void Flooding.receive(pack* msg, uint16_t src);
}