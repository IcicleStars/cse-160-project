interface Flooding{
    // command error_t send(pack msg, uint16_t dest);
    
    command error_t send(pack *msg, uint16_t dest, uint8_t payload_length);
    event void receive(pack* msg, uint16_t src);
    // event void Flooding.receive(pack* msg, uint16_t src);
}