print ("********************************************")
print ("*                                          *")
print ("*             TOSSIM Script                *")
print ("*                                          *")
print ("********************************************")

import sys
import time

from TOSSIM import *

t = Tossim([])


topofile="topology.txt"
modelfile="meyer-heavy.txt"

print ("Initializing mac...")
mac = t.mac()
print ("Initializing radio channels....")
radio=t.radio()
print ("    using topology file:",topofile)
print ("    using noise file:",modelfile)
print ("Initializing simulator....")
t.init()


simulation_outfile = "simulation.txt"
print("Saving sensors simulation output to:", simulation_outfile)
simulation_out = open(simulation_outfile, "w")
out = open(simulation_outfile, "w")

#out = sys.stdout

# Add debug channel

channels = ["setting", "message", "pairing_message", "pairing_resp_message", "info_message", "ack", "pairing_ack", "pairing_resp_ack", "info_ack", "radio_send","radio_status","boot","pairing_timer","info_timer","radio_send","oor_timer","missing_alarm","falling_alarm"]
#["Radio","Pairing","TimerPairing","Radio_ack","Radio_sent","Radio_rec","Radio_pack","OperationalMode","Info","Sensors"]
for channel in channels:
    print ("Activate debug message on channel ", channel)
    t.addChannel(channel,out)

print "Creating node 0...";
node0 =t.getNode(0);
time0 = 0*t.ticksPerSecond();
node0.bootAtTime(time0);
print ">>>Will boot at time",  time0/t.ticksPerSecond(), "[sec]";

print "Creating node 1...";
node1 = t.getNode(1);
time1 = 0*t.ticksPerSecond();
node1.bootAtTime(time1);
print ">>>Will boot at time", time1/t.ticksPerSecond(), "[sec]";

print "Creating node 2...";
node2 = t.getNode(2);
time2 = 0*t.ticksPerSecond();
node2.bootAtTime(time2);
print ">>>Will boot at time", time2/t.ticksPerSecond(), "[sec]";

print "Creating node 3...";
node3 = t.getNode(3);
time3 = 0*t.ticksPerSecond();
node3.bootAtTime(time3);
print ">>>Will boot at time", time3/t.ticksPerSecond(), "[sec]";

print("Creating radio channels...")
f = open(topofile, "r")
lines = f.readlines()
for line in lines:
    s = line.split()
    if (len(s) > 0):
        print (">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm")
        radio.add(int(s[0]), int(s[1]), float(s[2]))


# Creating channel model
print ("Initializing Closest Pattern Matching (CPM)...")
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0
mid_compl = 0

print ("Reading noise model data file:", modelfile)
print ("Loading:")
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl
            mid_compl = 0
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(0, 4):
            t.getNode(i).addNoiseTraceReading(val)
print("Done!")

for i in range(0, 4):
    print (">>>Creating noise model for node: ",i)
    t.getNode(i).createNoiseModel()


print ("Start simulation with TOSSIM! \n\n\n")
node1off = False

simtime = t.time()
while (t.time() < simtime + (200 * t.ticksPerSecond())):
	t.runNextEvent()
	if(node1off == False):
		if (t.time() >= (30 * t.ticksPerSecond())): 
			node1.turnOff()
			node1Off = True
		if (t.time() >= (110 * t.ticksPerSecond())): 
			node1.turnOn()
			node1Off = False
	
print ("\n\n\nSimulation finished!")

