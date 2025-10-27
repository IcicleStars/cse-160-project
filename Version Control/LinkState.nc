interface LinkState { 
    
    command void initialize();
    command uint16_t getNextHop(uint16_t dest);
    command void removeLink(uint16_t neighborId);
}