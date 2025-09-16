interface LinkLayer{
    command error_t send(pack msg, uint16_t dest);
    event void receive(pack* msg, uint16_t src);
}