from TestSim import TestSim
import sys

def main(): 
    s = TestSim()
    s.runTime(1)

    # load layout
    s.loadTopo("circle.topo")

    # add noise model
    s.loadNoise("no_noise.txt")

    # turn on nodes
    s.bootAll()

    #add channels
    s.addChannel(s.COMMAND_CHANNEL, sys.stdout)
    s.addChannel(s.GENERAL_CHANNEL, sys.stdout)
    s.addChannel(s.TRANSPORT_CHANNEL, sys.stdout)

    # let neighbors discover each other
    s.runTime(2000)

    # start tcp 
    s.testServer(1, 80)

    s.runTime(100)

    # Node 5 starts client, connect to 1:80 from :40
    s.testClient(5, 1, 40, 80)

    s.runTime(100)

    s.clientClose(5, 1, 40, 80)

    s.runTime(100)

if __name__ == '__main__': 
    main()