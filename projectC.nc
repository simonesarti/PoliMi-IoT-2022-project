#include "project.h"
#include "Timer.h"
#include "stdio.h"
#include "string.h"


module projectC {

  uses {
    //****** INTERFACES *****//
	interface Boot; 
    
	interface Timer<TMilli> as Pairing_Timer;
	interface Timer<TMilli> as Info_Timer;
	interface Timer<TMilli> as OutOfRange_Timer;
	interface Alarm as FallingAlarm;
	interface Alarm as MissingAlarm;

	interface Read<uint16_t> as Read;

    interface Receive;
    interface AMSend;
    interface SplitControl;
    interface Packet;
	interface PacketAcknowledgements;

	//interface SerialControl;	
  }
} 

implementation {

  	message_t packet;
  	bool locked;
  	bool paired;
  	uint8_t paired_with;
	uint8_t received_from;
	char key[20];
  	mote_type_t mote_type;
  	kinematic_status_t kinematic_status;
	
  	uint16_t sensor_read;
	msg_type_t type_message;

	uint16_t pairing_Tms=5000; //5s
	uint16_t info_Tms=10000;	//10s
	uint16_t outofrange_Tms=60000; //60s

	uint16_t last_x;
	uint16_t last_y;
	kinematic_status_t last_kinematic_status;
  	
  	char strings[2][20]={"qwertyuiopasdfghjklz","zlkjhgfdsapoiuytrewq"};


//*****************FUNCTION DECLARATIONS*******************
	void set_mote_type();
	void set_default_string();
	void set_initial_parameters();
	
	my_msg_t* fill_pairing_msg();
	my_msg_t* fill_pairing_resp();  
	my_msg_t* fill_info_msg(bool isResend);
	
	void send_broadcast_key();
	void send_pairing_resp();
	void send_info_message(bool isResend);
	
//*****************FUNCTION DEFINITIONS*******************
	
	void set_mote_type(){
		
		if(TOS_NODE_ID%2==0){
			mote_type=PARENT;
		}else{
			mote_type=CHILDREN;
		}
		dbg("setting", "Mote%u set to type %u\n",TOS_NODE_ID,mote_type);
	}
	
	void set_default_string(){
		
		uint8_t idx=(uint8_t)(TOS_NODE_ID/2);
		strcpy(key,strings[idx]);
		
		dbg("setting", "Mote%u set key to %s\n",TOS_NODE_ID,key);
	}
	
	void set_initial_parameters(){
		
		locked=FALSE;
		paired=FALSE;
		set_mote_type();
		set_default_string();
		
	}

	my_msg_t* fill_pairing_msg(){
		
		//create the message
		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		if (msg == NULL) {
			dbgerror("pairing_message", "failed to create the PAIRING message\n");
			return NULL;
		}
		
		//fill fields
		msg->msg_type = PAIRING;
		msg->senderID = TOS_NODE_ID;
		strcpy(msg->key, key);
		msg->x = 0;
		msg->y = 0;
		msg->kinematic_status = NONE;
		
		dbg("pairing_message", "Mote%u set fields for the PAIRING message. senderID:%u, key:%s, x:%u, y:%u, kin_status:%u \n",
		TOS_NODE_ID, msg->senderID, msg->key, msg->x, msg->y, msg->kinematic_status);
		
		//request ack
		//call PacketAcknowledgements.requestAck(&packet);
		//dbg("pairing_ack", "Mote%u Setting ack flag for the PAIRING message\n",TOS_NODE_ID);		
		
		return msg;
	}

	my_msg_t* fill_pairing_resp(){
		
		//create the message
		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		if (msg == NULL) {
			dbgerror("pairing_resp_message", "failed to create the PAIRING RESPONSE message\n");
			return NULL;
		}
		
		//fill fields
		msg->msg_type = PAIRING_RESP;
		msg->senderID = TOS_NODE_ID;
		strcpy(msg->key, "xxxxxxxxxxxxxxxxxxxx");
		msg->x = 0;
		msg->y = 0;
		msg->kinematic_status = NONE;
		
		dbg("pairing_resp_message", "Mote%u set fields for the PAIRING RESPONSE message, senderID:%u, key:%s, x:%u, y:%u, kin_status:%u \n",
		TOS_NODE_ID, msg->senderID, msg->key, msg->x, msg->y, msg->kinematic_status);

		//request ack
		call PacketAcknowledgements.requestAck(&packet);
		dbg("pairing_resp_ack", "Mote%u Setting ack flag for the PAIRING RESPONSE message\n",TOS_NODE_ID);

		return msg;
	}
	
	my_msg_t* fill_info_msg(bool isResend){
		
		//create the message
		my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
		if (msg == NULL) {
			dbgerror("info_message", "failed to create the INFO message\n");
			return NULL;
		}
		
		//fill fields
		msg->msg_type = INFO;
		msg->senderID = TOS_NODE_ID;
		strcpy(msg->key, "xxxxxxxxxxxxxxxxxxxx");

		if(!isResend){
			
			call Read.read();
			msg->x=sensor_read;
			last_x=sensor_read;
			
			call Read.read();
			msg->y=sensor_read;
			last_y=sensor_read;
			
			call Read.read();
			//from int16 to probability
			if(sensor_read>=(uint16_t)(65536*0.0) && sensor_read<(uint16_t)(65536*0.3))	{last_kinematic_status = STANDING;}
			if(sensor_read>=(uint16_t)(65536*0.3) && sensor_read<(uint16_t)(65536*0.6))	{last_kinematic_status = WALKING; }
			if(sensor_read>=(uint16_t)(65536*0.6) && sensor_read<(uint16_t)(65536*0.9))	{last_kinematic_status = RUNNING; }
			if(sensor_read>=(uint16_t)(65536*0.9) && sensor_read<(uint16_t)(65536*1.0))	{last_kinematic_status = FALLING; }
			msg->kinematic_status = last_kinematic_status;

			sensor_read=0;
		}
		else{
			msg->x=last_x;
			msg->y=last_y;
			msg->kinematic_status = last_kinematic_status;
		}
		
		dbg("info_message", "Mote%u set fields for the INFO message. senderID:%u, key:%s, x:%u, y:%u, kin_status:%u, isResend:%u \n",
		TOS_NODE_ID, msg->senderID, msg->key, msg->x, msg->y, msg->kinematic_status, isResend);
		
		//request ack
		call PacketAcknowledgements.requestAck(&packet);
		dbg("info_ack", "Mote%u Setting ack flag for the INFO message\n",TOS_NODE_ID);

		return msg;		
	}
	
	void send_broadcast_key(){
	
		my_msg_t* msg=fill_pairing_msg();
		
		if (msg != NULL) {
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%u is broadcasting the PAIRINIG message\n", TOS_NODE_ID);
				dbg_clear("radio_send", " at time %s \n", sim_time_string());	
				
				locked = TRUE;
				dbg("radio_status", "radio on mote%u has been locked\n",TOS_NODE_ID);
			}
		}
	}
	
	// TODO check received_from
	void send_pairing_resp(){
		
		my_msg_t* msg = fill_pairing_resp();
		
		if (msg != NULL) {
			
			if (call AMSend.send(received_from, &packet, sizeof(my_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%u sending unicast reply to the PAIRINIG message to mote%u\n", TOS_NODE_ID,received_from);
				dbg_clear("radio_send", " at time %s \n", sim_time_string());	
				
				locked = TRUE;
				dbg("radio_status", "radio on mote%u has been locked\n",TOS_NODE_ID);
			}
			
			
		}
	}
	
	void send_info_message(bool isResend){
		
		my_msg_t* msg=fill_info_msg(isResend);
		
		if (msg != NULL) {
			
			if (call AMSend.send(paired_with, &packet, sizeof(my_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%u is broadcasting the INFO message\n", TOS_NODE_ID);
				dbg_clear("radio_send", " at time %s \n", sim_time_string());	
				
				locked = TRUE;
				dbg("radio_status", "radio on mote%u has been locked\n",TOS_NODE_ID);
			}
		}
		
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
      		
      		dbg("radio_status","Radio ON on mote%u!\n", TOS_NODE_ID);
			if (!paired){
				call Pairing_Timer.startPeriodic(pairing_Tms);
				dbg("pairing_timer","Started PAIRING TIMER on mote%u (not already paired)\n",TOS_NODE_ID);
			}
			else{
				if(mote_type==CHILDREN){
					call Info_Timer.startPeriodic(info_Tms);
					dbg("info_timer","Started INFO TIMER on mote%u (already paired)\n",TOS_NODE_ID);

				}
				
			}
				
    	}else{
      		
      		dbgerror("radio_status", "Radio failed to start on node %u, retrying...\n",TOS_NODE_ID);
      		call SplitControl.start();
    	}
    	
  	}
  
  	event void SplitControl.stopDone(error_t err){
    	dbg("radio_status", "Radio on mote%u stopped!\n", TOS_NODE_ID);
  	}

//***************** Timer interfaces ********************//
  	
	/* This event is triggered every time the timer fires.*/
  	event void Pairing_Timer.fired() {

    	dbg("pairing_timer", "Timer fired\n");
    
    	if (locked) {
      		dbg("radio_send", "Radio on mote%u was locked when timer fired, do nothing\n");

    	}else {
			dbg("radio_send", "Radio on mote%u not locked, sending the PAIRING message\n");
			send_broadcast_key();
   		}  
  	}

  	/* This event is triggered every time the timer fires.*/
  	event void Info_Timer.fired() {

    	dbg("info_timer", "Timer fired\n");
    
    	if (locked) {
      		dbg("radio_send", "Radio on mote%u was locked when timer fired, do nothing\n");

    	}else {
			dbg("radio_send", "Radio on mote%u not locked, sending the INFO message\n");
			send_info_message(FALSE);
   		}  
  	}
  
	/* This event is triggered every time the timer fires.*/
  	event void OutOfRange_Timer.fired() {

		dbg("oor_timer", "Timer fired\n");
		
		dbg("missing_alarm", " Mote%u has not received messages from childer for more than 10s. Last known position was (x:%u, y:%u)\n",
		 TOS_NODE_ID, last_x, last_y);
		call MissingAlarm.start();

	}
	
	//***************** Alarm interfaces ********************//
	event void FallingAlarm.fired(){};
	event void MissingAlarm.fired(){};
	

  //********************* AMSend interface ****************//
  	event void AMSend.sendDone(message_t* buf, error_t err) {
	/* This event is triggered when a message is sent */
	
		// 1. Check if the packet is sent
		if (err != SUCCESS){
			dbgerror("radio_send", "Packet sending from mote%u failed to be sent\n", TOS_NODE_ID);
			return;	
		}
		else {
			dbg("radio_send", "Packet sending from mote%u sent correctly\n", TOS_NODE_ID);
			
			locked = FALSE;
			dbg("radio_status", "radio on mote%u has been unlocked\n",TOS_NODE_ID);


			//open-close section just because tinyos doesn't like the debug otherwise
			{
			
			//parse the message
			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(buf, sizeof(my_msg_t));
			if (msg == NULL){
				dbgerror("message", "failed to parse the sent message in sendDone\n");
				return;
			}

			//deal with acks
			if (!call PacketAcknowledgements.wasAcked(buf)){
				
				if(msg->msg_type == PAIRING_RESP){ 
					send_pairing_resp();
					dbg("pairing_resp_ack","PAIRING RESP ACK not received by mote%u, resending...\n",TOS_NODE_ID);
				}
				if(msg->msg_type == INFO){
					send_info_message(TRUE); 
					dbg("info_ack","INFO ACK not received by mote%u, resending...\n",TOS_NODE_ID);
				}
			}
			else{
				
				if(msg->msg_type == PAIRING_RESP){
					dbg("pairing_resp_ack","PAIRING RESP ACK received by mote%u\n",TOS_NODE_ID);
					if(mote_type == CHILDREN){
						call Info_Timer.startPeriodic(info_Tms);
						dbg("info_timer","starting INFO timer on mote%u\n",TOS_NODE_ID);	
					}
				}
				if (msg->msg_type == INFO){
					dbg("info_ack","INFO ACK received by mote%u\n",TOS_NODE_ID);
				}
			}
		}
		}
		return;
	}	

  //***************************** Receive interface *****************//
  	
	/* This event is triggered when a message is received */
	event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
	
	 	
		//check size of message
	 	if (len != sizeof(my_msg_t)) {
			dbgerror("message", "failed to read the content of the received message\n");
 	 	}
		
		else{
			
			//get the payload
			my_msg_t* rec_msg = (my_msg_t*)payload;
			

			if(rec_msg->msg_type == PAIRING){
			
				if (strcmp(key, rec_msg->key) == 0){
					received_from = rec_msg->senderID;
					send_pairing_resp();
					dbg("message", "mote%u received PAIRING MESSAGE from mote%u, sending PAIRING RESP\n",
					TOS_NODE_ID, received_from);
				} 

			}

			if(rec_msg->msg_type == PAIRING_RESP){
				
				paired_with = rec_msg->senderID;
				paired = TRUE;

				call Pairing_Timer.stop();
				dbg("pairing_timer","stopping PAIRING timer on mote%u\n",TOS_NODE_ID);
				
				dbg("message", "mote%u received PAIRING RESP from mote%u. Paired the two\n",
				TOS_NODE_ID,paired_with);
			}

			if(rec_msg->msg_type == INFO){
				
				if(rec_msg->senderID == paired_with){
					
					dbg("info_message", "mote%u received INFO from PAIRED mote%u\n",TOS_NODE_ID, paired_with);
					last_x = rec_msg->x;
					last_y = rec_msg->y; 
					
					if(rec_msg->kinematic_status == FALLING){
						dbg("falling_alarm", " Children has fallen, go pick him up at position (x:%u, y:%u)\n",
						TOS_NODE_ID,last_x,last_y);
						call FallingAlarm.start();
					}
					
					call OutOfRange_Timer.startOneShot(outofrange_Tms);
					dbg("oor_timer", "mote%u started OutOfRange TIMER countdown\n",TOS_NODE_ID);

					
				}
			}

		}

		return buf;

  }


    //***************** Read interface **********************//
	
	/* This event is triggered when the fake sensor finish to read (after a Read.read()) */
	event void Read.readDone(error_t result, uint16_t data){
		
		sensor_read=data;
		
	}
  
  
}

