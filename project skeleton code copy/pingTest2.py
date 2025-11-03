from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("circle.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    # let neighbors discover each other.
    s.runTime(20);

    # After sending a ping, simulate a little to prevent collision.
    s.runTime(750);
    # s.routeDMP(19);
    # s.runTime(3);
    s.ping (18, 4, "Test1")
    s.runTime(45);

    # s.routeDMP(5);
    s.routeDMP(5);
    s.runTime(5);
    s.moteOff(6);
    s.runTime(750);

    s.ping(5, 8, "Test2");
    s.runTime(45);

    s.routeDMP(10);

if __name__ == '__main__':
    main()
