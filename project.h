#ifndef PROJECT_H
#define PROJECT_H

typedef struct info_msg 
{
	uint16_t x;
	uint16_t y;
	kinematic_status_t kinetic_status;
		
} info_msg_t;

typedef struct pairing_msg 
{
	uint8_t senderID;
	char key[20];
		
} pairing_msg_t;

typedef struct pairing_resp 
{
	uint8_t responderID;
		
} pairing_resp_t;
 

enum msg_enum
{
	AM_MY_MSG = 6
	
} msg_enum;

enum mote_type
{
	PARENT = 0,
	CHILDREN = 1
	
} mote_type_t;

enum kinematic_status
{
	STANDING = 0,
	WALKING = 1,
	RUNNING = 2,
	FALLING =3
	
} kinematic_status_t;

enum msg_type
{
	PAIRING = 0,
	PAIRING_RESP=1,
	INFO = 2
	
} msg_type_t;

#endif
