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
    s.runTime(260)

    s.testServer(1, 80)

    s.runTime(100)

    # start several clients
    s.testClient(5, 1, 60000, 80)
    s.runTime(10)
    s.testClient(7, 1, 60001, 80)
    s.runTime(10)
    s.testClient(17, 1, 60002, 80)

    s.runTime(1000)

    s.clientClose(5, 1, 60000, 80)
    s.clientClose(7, 1, 60001, 80)
    s.clientClose(17, 1, 60002, 80)

    s.runTime(700)

if __name__ == '__main__': 
    main()