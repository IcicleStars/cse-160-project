from TestSim import TestSim
import sys

def main(): 
    s = TestSim()
    s.runTime(1)

    # load layout
    s.loadTopo("circle.topo")

    # add noise model
    s.loadNoise("light_noise.txt")

    # turn on nodes
    s.bootAll()

    #add channels
    s.addChannel(s.COMMAND_CHANNEL, sys.stdout)
    s.addChannel(s.GENERAL_CHANNEL, sys.stdout)
    s.addChannel(s.TRANSPORT_CHANNEL, sys.stdout)

    # let neighbors discover each other
    s.runTime(240)

    s.testServer(1, 80)

    s.runTime(100)

    
    s.testClient(5, 1, 60000, 80)

    s.runTime(500)

    s.clientClose(5, 1, 60000, 80)

    s.runTime(500)

if __name__ == '__main__': 
    main()