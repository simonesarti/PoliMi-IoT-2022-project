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


#simulation_outfile = "simulation.txt"
#print "Saving sensors simulation output to:", simulation_outfile
#simulation_out = open(simulation_outfile, "w")

#out = open(simulation_outfile, "w")
out = sys.stdout

# Add debug channel

channels = ["setting", "message", "radio_send", "radio_status","boot","pairing_timer","info_timer","radio_send","oor_timer","missing_alarm","falling_alarm"]
#["Radio","Pairing","TimerPairing","Radio_ack","Radio_sent","Radio_rec","Radio_pack","OperationalMode","Info","Sensors"]
for channel in channels:
    print (f"Activate debug message on channel {channel}")
    t.addChannel(channel,out)

node0, node1, node2, node2 = None, None, None, None
time0,time1,time2,time3 = None, None, None, None

for i,time,node in zip([0,1,2,3],[time0,time1,time2,time3], [node0, node1, node2, node2]):

    print (f"Creating node {i}...")
    node = t.getNode(i)
    time = 0*t.ticksPerSecond()
    node.bootAtTime(time)
    print (f">>>Will boot at time",  time/t.ticksPerSecond(), "[sec]")


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
    print (f">>>Creating noise model for node: {i}")
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
	
print ("\n\n\nSimulation finished!")

