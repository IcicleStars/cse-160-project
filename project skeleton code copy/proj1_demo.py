from TestSim import TestSim

def main():
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);

    s.runTime(10);
    s.neighborDMP(5);

    s.runTime(1);
    s.ping(3, 18, "Test1");

    s.runTime(2);
    s.moteOff(5);

    s.runTime(1);
    s.ping(4, 7, "Test2");

    s.runTime(100);
    s.neighborDMP(6);
    s.runTime(50);


if __name__ == '__main__':
    main()
