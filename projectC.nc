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

	interface Read<info_data_t> as FakeSensor;

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
	uint8_t retransmittion_counter=0;
  	bool locked = FALSE;
  	bool paired = FALSE;
  	uint8_t paired_with = 255;
	char key[21];	//last for \0 character
  	mote_type_t mote_type;
  	kinematic_status_t kinematic_status;
	
  	info_data_t sensor_read;
	msg_type_t type_message;

	uint16_t pairing_Tms=5000; //5s
	uint16_t info_Tms=10000;	//10s
	uint16_t outofrange_Tms=60000; //60s

	uint16_t last_x;
	uint16_t last_y;
	kinematic_status_t last_kinematic_status;
  	
  	char string1[21]={"qwertyuiopasdfghjklz"}; 
  	char string2[21]={"zlkjhgfdsapoiuytrewq"};


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
	
	const char* string_mote_type(mote_type_t mote_type);
	const char* string_msg_type(msg_type_t msg_type);
	const char* string_ks(kinematic_status_t ks);
	
//*****************FUNCTION DEFINITIONS*******************
	
	void set_mote_type(){
		
		if(TOS_NODE_ID%2==0){
			mote_type=PARENT;
		}else{
			mote_type=CHILD;
		}
		dbg("setting", "Mote%hhu set to type %s\n",TOS_NODE_ID,string_mote_type(mote_type));
	}
	
	void set_default_string(){
		
		if(((uint8_t)(TOS_NODE_ID/2))==0){strcpy(key,string1);}
		if(((uint8_t)(TOS_NODE_ID/2))==1){strcpy(key,string2);}
				
		dbg("setting", "Mote%hhu set key to %s\n",TOS_NODE_ID,key);
	}
	
	void set_initial_parameters(){
		
		locked=FALSE;
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
		
		dbg("pairing_message", "Mote%hhu set fields for the PAIRING message. senderID:%hhu, key:%s, x:%u, y:%u, kin_status:%s \n",
		TOS_NODE_ID, msg->senderID, msg->key, msg->x, msg->y, string_ks(msg->kinematic_status));
		
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
		strcpy(msg->key, key);
		msg->x = 0;
		msg->y = 0;
		msg->kinematic_status = NONE;
		
		dbg("pairing_resp_message", "Mote%hhu set fields for the PAIRING RESPONSE message, senderID:%hhu, key:%s, x:%u, y:%u, kin_status:%s \n",
		TOS_NODE_ID, msg->senderID, msg->key, msg->x, msg->y, string_ks(msg->kinematic_status));

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
		strcpy(msg->key, key);

		if(!isResend){
			
			call FakeSensor.read();
			
			msg->x=sensor_read.x;
			last_x=sensor_read.x;
			
			msg->y=sensor_read.y;
			last_y=sensor_read.y;
			
			//from int16 to probability
			if(sensor_read.kinematic_status >=(uint16_t)(65536*0.0) && sensor_read.kinematic_status <(uint16_t)(65536*0.3))	{last_kinematic_status = STANDING;}
			if(sensor_read.kinematic_status >=(uint16_t)(65536*0.3) && sensor_read.kinematic_status <(uint16_t)(65536*0.6))	{last_kinematic_status = WALKING; }
			if(sensor_read.kinematic_status >=(uint16_t)(65536*0.6) && sensor_read.kinematic_status <(uint16_t)(65536*0.9))	{last_kinematic_status = RUNNING; }
			if(sensor_read.kinematic_status >=(uint16_t)(65536*0.9) && sensor_read.kinematic_status <(uint16_t)(65536*1.0))	{last_kinematic_status = FALLING; }
			msg->kinematic_status = last_kinematic_status;

		}
		else{
			msg->x=last_x;
			msg->y=last_y;
			msg->kinematic_status = last_kinematic_status;
		}
		
		dbg("info_message", "Mote%hhu set fields for the INFO message. senderID:%hhu, key:%s, x:%u, y:%u, kin_status:%s, isResend:%u \n",
		TOS_NODE_ID, msg->senderID, msg->key, msg->x, msg->y, string_ks(msg->kinematic_status), isResend);
		
		//request ack
		call PacketAcknowledgements.requestAck(&packet);
		dbg("info_ack", "Mote%hhu Setting ack flag for the INFO message\n",TOS_NODE_ID);

		return msg;		
	}
	
	void send_broadcast_key(){
	
		my_msg_t* msg = fill_pairing_msg();
		
		if (msg != NULL) {
			
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%hhu is broadcasting the PAIRINIG message at time %s\n", TOS_NODE_ID, sim_time_string());	
				dbg("radio_status", "radio on mote%hhu has been locked\n",TOS_NODE_ID);
				locked = TRUE;
				
			}
		}
	}
	
	void send_pairing_resp(){
		
		my_msg_t* msg = fill_pairing_resp();
		
		if (msg != NULL) {
			
			if (call AMSend.send(paired_with, &packet, sizeof(my_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%hhu sending unicast reply to the PAIRINIG message to mote%hhu at time %s \n", TOS_NODE_ID,paired_with, sim_time_string());
				dbg("radio_status", "radio on mote%hhu has been locked\n",TOS_NODE_ID);
				locked = TRUE;
				
			}
			
			
		}
	}
	
	void send_info_message(bool isResend){
		
		my_msg_t* msg=fill_info_msg(isResend);
		
		if (msg != NULL) {
			
			if (call AMSend.send(paired_with, &packet, sizeof(my_msg_t)) == SUCCESS) {
				
				dbg("radio_send", "mote%hhu is sending the INFO message at time %s\n", TOS_NODE_ID, sim_time_string());
				dbg("radio_status", "radio on mote%hhu has been locked\n",TOS_NODE_ID);
				locked = TRUE;
				
			}
		}
		
	}
	
	const char* string_mote_type(mote_type_t mote_type){
		if(mote_type==PARENT){return "PARENT";}
		if(mote_type==CHILD){return "CHILD";}
	}
	
	const char* string_msg_type(msg_type_t msg_type){
		if(msg_type==PAIRING){return "PAIRING";}
		if(msg_type==PAIRING_RESP){return "PAIRING_RESP";}
		if(msg_type==INFO){return "INFO";}
	}
	
	const char* string_ks(kinematic_status_t ks){
		if(ks==NONE){return "NONE";}
		if(ks==STANDING){return "STANDING";}
		if(ks==WALKING){return "WALKING";}
		if(ks==RUNNING){return "RUNNING";}
		if(ks==FALLING){return "FALLING";}
	}
	
//***************************MAIN***************************************************************************************************************************//

  
//***************** Boot interface ********************//
	event void Boot.booted() {
		
		dbg("boot","Application booted on node %hhu.\n",TOS_NODE_ID);
		set_initial_parameters();
		call SplitControl.start();
		
  	}

//***************** SplitControl interface ********************//
  	event void SplitControl.startDone(error_t err){
  		
  		if (err == SUCCESS) {
      		
      		dbg("radio_status","Radio ON on mote%hhu!\n", TOS_NODE_ID);
			if (!paired){
				dbg("pairing_timer","Started PAIRING TIMER on mote%hhu (not already paired)\n",TOS_NODE_ID);
				call Pairing_Timer.startPeriodic(pairing_Tms);
				
			}
			else{
				if(mote_type==CHILD){
					dbg("info_timer","Started INFO TIMER on mote%hhu (already paired)\n",TOS_NODE_ID);
					call Info_Timer.startPeriodic(info_Tms);
					

				}
				
			}
				
    	}else{
      		
      		dbgerror("radio_status", "Radio failed to start on node %hhu, retrying...\n",TOS_NODE_ID);
      		call SplitControl.start();
    	}
    	
  	}
  
  	event void SplitControl.stopDone(error_t err){
    	dbg("radio_status", "Radio on mote%hhu stopped!\n", TOS_NODE_ID);
  	}

//***************** Timer interfaces ********************//
  	
	/* This event is triggered every time the timer fires.*/
  	event void Pairing_Timer.fired() {

    	dbg("pairing_timer", "pairing Timer on mote%hhu fired\n", TOS_NODE_ID);
    
    	if (locked) {
      		dbg("radio_send", "Radio on mote%hhu was locked when timer fired, do nothing\n", TOS_NODE_ID);

    	}else {
			dbg("radio_send", "Radio on mote%hhu not locked, sending the PAIRING message\n", TOS_NODE_ID);
			send_broadcast_key();
   		}  
  	}

  	/* This event is triggered every time the timer fires.*/
  	event void Info_Timer.fired() {

    	dbg("info_timer", "info Timer on mote%hhu fired\n", TOS_NODE_ID);
    
    	if (locked) {
      		dbg("radio_send", "Radio on mote%hhu was locked when timer fired, do nothing\n", TOS_NODE_ID);

    	}else {
			dbg("radio_send", "Radio on mote%hhu not locked, sending the INFO message\n", TOS_NODE_ID);
			send_info_message(FALSE);
   		}  
  	}
  
	/* This event is triggered every time the timer fires.*/
  	event void OutOfRange_Timer.fired() {

		dbg("oor_timer", "out_of_range Timer on mote%hhu fired\n", TOS_NODE_ID);
		
		dbg("missing_alarm", " MISSING ALERT: Mote%hhu has not received messages from child for more than 60s. Last known position was (x:%u, y:%u)\n",
		 TOS_NODE_ID, last_x, last_y);

	}
	

  //********************* AMSend interface ****************//
  	event void AMSend.sendDone(message_t* buf, error_t err) {
	/* This event is triggered when a message is sent */
	
		// 1. Check if the packet is sent
		if (err != SUCCESS){
			dbgerror("radio_send", "Packet sending from mote%hhu failed to be sent\n", TOS_NODE_ID);
			return;	
		}
		else {
			dbg("radio_send", "Packet sending from mote%hhu sent correctly\n", TOS_NODE_ID);
			
			dbg("radio_status", "radio on mote%hhu has been unlocked\n",TOS_NODE_ID);
			locked = FALSE;
			


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
					dbg("pairing_resp_ack","PAIRING RESP ACK not received by mote%hhu, resending...\n",TOS_NODE_ID);
					send_pairing_resp();
					
				}
				if(msg->msg_type == INFO && retransmittion_counter<2){
					dbg("info_ack","INFO ACK not received by mote%hhu, resending...\n",TOS_NODE_ID);
					send_info_message(TRUE);
					retransmittion_counter++;
				}
				
			}
			else{
				
				if(msg->msg_type == PAIRING_RESP && paired){
					dbg("pairing_resp_ack","PAIRING RESP ACK received by mote%hhu\n",TOS_NODE_ID);
					if(mote_type == CHILD){
						dbg("info_timer","starting INFO timer on mote%hhu\n",TOS_NODE_ID);	
						call Info_Timer.startPeriodic(info_Tms);
						
					}
				}
				if (msg->msg_type == INFO){
					dbg("info_ack","INFO ACK received by mote%u\n",TOS_NODE_ID);
					retransmittion_counter=0;
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
			
			dbg("message", "mote%hhu received from mote%hhu\n", TOS_NODE_ID, rec_msg -> senderID);
			if(rec_msg->msg_type == PAIRING){
			
				if (strcmp(key, rec_msg->key) == 0){
					paired_with = rec_msg->senderID;
					dbg("message", "mote%hhu received PAIRING MESSAGE from mote%hhu with same key, sending PAIRING RESP\n",TOS_NODE_ID, paired_with);
					send_pairing_resp();
					
					
				} 

			}

			if(rec_msg->msg_type == PAIRING_RESP){
				paired=TRUE;
				dbg("message", "mote%hhu received PAIRING RESP from mote%hhu. Pairing with it\n",TOS_NODE_ID, paired_with);
				dbg("pairing_timer","stopping PAIRING timer on mote%hhu\n",TOS_NODE_ID);
				call Pairing_Timer.stop();
				
			}

			if(rec_msg->msg_type == INFO){
				
				if(rec_msg->senderID == paired_with){
					
					dbg("info_message", "mote%hhu received INFO from paired mote%hhu\n",TOS_NODE_ID, paired_with);
					last_x = rec_msg->x;
					last_y = rec_msg->y; 
					
					if(rec_msg->kinematic_status == FALLING){
						dbg("falling_alarm", " FALLING ALERT: Child has fallen, go pick him up at position (x:%hhu, y:%u)\n",TOS_NODE_ID,last_x,last_y);
					}
					dbg("oor_timer", "mote%hhu started OutOfRange TIMER countdown\n",TOS_NODE_ID);
					call OutOfRange_Timer.startOneShot(outofrange_Tms);
					

					
				}
			}

		}

		return buf;

  }


    //***************** Read interface **********************//
	
	/* This event is triggered when the fake sensor finish to read (after a FakeSensor.read()) */
	event void FakeSensor.readDone(error_t result, info_data_t data){
		
		sensor_read=data;
		
	}
  
  
}

