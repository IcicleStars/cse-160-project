generic configuration Flooding(int channel){
   provides interface Flooding;
}

implementation{
   components new FloodingP();
    Flooding = SimpleSendP.SimpleSend;

   components new TimerMilliC() as floodingTimer;
    FloodingP.floodingTimer -> floodingTimer; 

   components RandomC as Random; 
    FloodingP.Random -> Random;
    // allows the floodingP module to use the LinkLayer module
   components new LinkLayerC() as LinkLayer; 
    FloodingP.LinkLayer -> LinkLayer;
   
}