from TestSim import TestSim

def main():
    s = TestSim();
    s.runTime(1);
    s.loadTopo("long_line.topo");
    # Use a noise file that simulates packet loss
    s.loadNoise("no_noise.txt"); 
    s.bootAll();

    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL); # Add the neighbor channel
    
    # Run simulation long enough for the periodic timer to fire and drop a neighbor
    # You will need to simulate packet loss to trigger the link quality check
    s.runTime(40); # Run for 40 seconds to allow for at least 3 quality checks

    # Issue a neighbor dump command to a node (e.g., node 2)
    s.neighborDMP(2);
    s.runTime(5); # Run for a bit to see the output

if __name__ == '__main__':
    main()