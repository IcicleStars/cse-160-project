interface LinkState { 
    
    command void initialize();
    command uint16_t getNextHop(uint16_t dest);
    command void printTable();
    command void printLSA();

}