#include "project.h"
#include "Timer.h"


module projectC {

  uses {
    //****** INTERFACES *****//
	interface Boot; 
    interface Timer<TMilli> as MilliTimer;
	    
    interface Receive;
    interface AMSend;
    interface SplitControl;
    interface Packet;
	interface PacketAcknowledgements;
	 
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t> as Read;
  }
} 

implementation {

  	message_t packet;
  	bool locked;
  	bool paired;
  	uint8_t paired_with;
  	char key[20];
  	mote_type_t mote_type;
  	kinematic_status_t kinematic_status;
	
  	uint16_t sensor_read;
	msg_type_t type_message;
  	uint16_t ms=10000;
  	
  	
  	char strings[2][20];
  	strings[0]="qwertyuiopasdfghjklz";
  	strings[1]="zlkjhgfdsapoiuytrewq";


//*****************FUNCTION DECLARATIONS*******************
	void set_mote_type();
	void set_default_string();
	void set_initial_parameters();
	
	pairing_msg_t* fill_pairing_msg();
	pairing_resp_t* fill_pairing_resp();  
	info_msg_t* fill_info_msg();
	
	void broadcast_key();
	void unicast_pairing_resp();
	void send_info_message();

	uint8_t message_type_received(uint8_t len);
	
//*****************FUNCTION DEFINITIONS*******************
	
	void set_mote_type(){
		
		if(TOS_NODE_ID%2==0){
			mote_type=PARENT;
		}else{
			mote_type=CHILDREN;
		}
	}
	
	void set_default_string(){
		
		idx=uint8_t((TOS_NODE_ID-1)/2);
		key=strings[idx];
		
	}
	
	void set_initial_parameters(){
		
		locked=FALSE;
		paired=FALSE;
		set_mote_type();
		set_default_string();
		
	}
	
	pairing_msg_t* fill_pairing_msg(){
		
		pairing_msg_t* msg = (pairing_msg_t*)call Packet.getPayload(&packet, sizeof(pairing_msg_t));
		if (msg == NULL) {
			dbgerror("message", "failed to create the PAIRING message\n");
		return NULL;
		}
		
		msg->senderID=TOS_NODE_ID;
		msg->key=key;
		return msg;
	}

	pairing_resp_t* fill_pairing_resp(){

		pairing_resp_t* msg = (pairing_resp_t*)call Packet.getPayload(&packet, sizeof(pairing_resp_t));
		if (msg == NULL) {
			dbgerror("message", "failed to create the PAIRING RESPONSE message\n");
		return NULL;
		}
		
		msg->responderID=TOS_NODE_ID;
		return msg;


	}
	
	info_msg_t* fill_info_msg(){
		
		info_msg_t* msg = (info_msg_t*)call Packet.getPayload(&packet, sizeof(info_msg_t));
		if (msg == NULL) {
			dbgerror("message", "failed to create the INFO message\n");
		return NULL;
		}
		
		call Read.read();
		msg->x=sensor_read;
		
		call Read.read();
		msg->y=sensor_read;
		
		call Read.read();
		if(sensor_read>=0                   && sensor_read<uint16_t(65536*0.3))	{msg->kinetic_status = STANDING;}
		if(sensor_read>=uint16_t(65536*0.3) && sensor_read<uint16_t(65536*0.6))	{msg->kinetic_status = WALKING; }
		if(sensor_read>=uint16_t(65536*0.6) && sensor_read<uint16_t(65536*0.9))	{msg->kinetic_status = RUNNING; }
		if(sensor_read>=uint16_t(65536*0.9) && sensor_read<uint16_t(65536)    )	{msg->kinetic_status = FALLING; }
		
		sensor_read=0;
		
		return msg;		
	}
	
	void broadcast_key(){
	
		pairing_msg_t* msg=fill_pairing_msg();
		
		if (msg != NULL) {
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(pairing_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%u is broadcasting the PAIRINIG message\n", TOS_NODE_ID);
				dbg_clear("radio_send", " at time %s \n", sim_time_string());	
				
				locked = TRUE;
				dbg("radio", "radio on mote%u has been locked\n",TOS_NODE_ID);
			}
		}
	}
	
	void unicast_pairing_resp(){
		
		pairing_resp_t* msg = fill_pairing_resp();
		
		if (msg != NULL) {
			
			if (call AMSend.send(paired_with, &packet, sizeof(pairing_resp_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%u sending unicast reply to the PAIRINIG message to mote%u\n", TOS_NODE_ID,paired_with);
				dbg_clear("radio_send", " at time %s \n", sim_time_string());	
				
				locked = TRUE;
				dbg("radio", "radio on mote%u has been locked\n",TOS_NODE_ID);
			}
			
			
		}
	}
	
	void send_info_message(){
		
		info_msg_t* msg=fill_info_msg();
		
		if (msg != NULL) {
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(info_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%u is broadcasting the INFO message\n", TOS_NODE_ID);
				dbg_clear("radio_send", " at time %s \n", sim_time_string());	
				
				locked = TRUE;
				dbg("radio", "radio on mote%u has been locked\n",TOS_NODE_ID);
			}
		}
		
	}
	
	uint8_t message_type_received(uint8_t len){

		if (len == sizeof(pairing_msg_t)) {return PAIRING;}
		if (len == sizeof(pairing_resp_t)) {return PAIRING_RESP;}
		if (len == sizeof(info_msg_t)) {return INFO;}
		
		return 999;
	}
	
//***************************MAIN***************************************************************************************************************************//

  
  //***************** Boot interface ********************//
	event void Boot.booted() {
		
		dbg("boot","Application booted on node %u.\n",TOS_NODE_ID);
		call SplitControl.start();
		set_initial_parameters();
		
  	}

  //***************** SplitControl interface ********************//
  	event void SplitControl.startDone(error_t err){
  		
  		if (err == SUCCESS) {
      		
      		dbg("radio","Radio ON on mote%u!\n", TOS_NODE_ID);
			broadcast_key();
   	
    	}else{
      		
      		dbgerror("radio", "Radio failed to start on node %u, retrying...\n",TOS_NODE_ID);
      		call SplitControl.start();
    	}
    	
  	}
  
  	event void SplitControl.stopDone(error_t err){
    	dbg("radio", "Radio on mote%u stopped!\n", TOS_NODE_ID);
  	}

  //***************** MilliTimer interface ********************//
  	
  	/* This event is triggered every time the timer fires.*/
  	event void MilliTimer.fired() {

    	dbg("timer", "\n\nTimer fired, counter is %hu.\n", counter);
    
    	if (locked) {
      		
      		dbg("radio_send", "Radio on mote%u was locked when timer fired, do nothing\n");

    	}else {
			
			dbg("radio_send", "Radio on mote%u not locked, sending the INFO message\n");
			send_info_message();
   		}  
  	}
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf, error_t err) {
	/* This event is triggered when a message is sent */
/*	
	// 1. Check if the packet is sent
	if (err != SUCCESS){
	    dbgerror("radio_send", "Packet sending from mote%u failed to be sent\n", TOS_NODE_ID);	
	}
	else {
		dbg("radio_send", "Packet sending from mote%u sent correctly\n", TOS_NODE_ID);
		
		locked = FALSE;
		dbg("radio", "radio on mote%u has been unlocked\n",TOS_NODE_ID);
		
		{
		//parse the message
		my_msg_t* rcm = (my_msg_t*)call Packet.getPayload(buf, sizeof(my_msg_t));
		if (rcm == NULL){
			dbgerror("message", "failed to parse the sent message in sendDone\n");
			return;
		}
		// 2. Check if the ACK is received (read the docs)	
		// 2a. If yes, stop the timer when the program is done
		// 2b. Otherwise, send again the request
		if (!call PacketAcknowledgements.wasAcked(buf)){
			if(TOS_NODE_ID==2){
				dbg("radio_ack", "ack not received by mote%u, trying to send packet again\n",TOS_NODE_ID);
				sendPacket(rcm->msg_type,rcm->value);
			}
			else{
				dbg("radio_ack", "ack not received by mote%u, waiting for next timer cycle to resend\n",TOS_NODE_ID);
				//do nothing, wait for next timer
			}
			
		
		}else{
			dbg("radio_ack", "ack received by mote%u\n",TOS_NODE_ID);			
			if(TOS_NODE_ID==1){
				n_received_acks++;
				dbg("radio_ack", "number of REQ_ACK received is %u\n",n_received_acks);	
				if(n_received_acks==x){
					call MilliTimer.stop();
		  			dbg("timer","stopping timer\n");
				}	
			}
		}
		}
		
	}
*/
  }

  //***************************** Receive interface *****************//
  	event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
		/* This event is triggered when a message is received */
	 	// 1. Read the content of the message
	 
	 	message_type_received=message_type_received(len);
		switch(message_type_received){

			case(PAIRING):{
				pairing_msg_t* msg = (pairing_msg_t*)payload;
				//TODO
				break;
			}

			case(PAIRING_RESP):{
				pairing_resp_t* msg = (pairing_resp_t*)payload;
				//TODO
				break;
			}

			case(INFO):{
				info_msg_t* msg = (info_msg_t*)payload;
				//TODO
				break;
			}
			
			default:{
				dbgerror("message", "failed to read the content of the received message\n");
				break;
			}
		}
	 
/*	 
		//TODO
		dbg("radio_rec", "Received packet at time %s\n", sim_time_string());
		dbg("radio_pack",">>>Pack \n \t Payload length %u \n", call Packet.payloadLength(buf));
		
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t counter: %u \n", rcm->counter);
		dbg_clear("radio_pack", "\t\t value: %u \n", rcm->value);
		dbg_clear("radio_pack", "\t\t msg_type: %u \n", rcm->msg_type);	
*/	 		  
		return buf;

  }


    //***************** Read interface **********************//
	
	/* This event is triggered when the fake sensor finish to read (after a Read.read()) */
	event void Read.readDone(error_t result, uint16_t data){
		
		sensor_read=data;
		
	}
  
  
}

