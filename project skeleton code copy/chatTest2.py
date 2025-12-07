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
    # s.addChannel(s.COMMAND_CHANNEL, sys.stdout)
    s.addChannel(s.GENERAL_CHANNEL, sys.stdout)
    # s.addChannel(s.ROUTING_CHANNEL, sys.stdout)
    # s.addChannel(s.TRANSPORT_CHANNEL, sys.stdout)

    # let neighbors discover each other
    s.runTime(300)

    # start tcp 

    s.testServer(1, 41)
    s.runTime(60)

    s.hello(5, 1, 101, "Ice")
    s.runTime(50)

    s.hello(18, 1, 102, "Jaden")
    s.runTime(50)

    s.broadcast_message(5, "Hello?")
    s.runTime(30)
    s.unicast_message(18, "Ice", "Hi") 
    s.runTime(30)

    s.listUsers(5)
    s.runTime(30)

    s.clientClose(5, 1, 101, 41)
    s.runTime(10)
    s.clientClose(18, 1, 403, 41)
    s.runTime(20)

if __name__ == '__main__': 
    main()