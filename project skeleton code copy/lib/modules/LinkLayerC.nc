generic configuration LinkLayer(int channel){
   provides interface LinkLayer;
}

implementation{
   components new LinkLayerP();
   LinkLayer = SimpleSendP.SimpleSend;

   components new TimerMilliC() as linkLayerTimer;
   LinkLayerP.linkLayerTimer -> linkLayerTimer; 

   components RandomC as Random; 
   LinkLayerP.Random -> Random; 

}