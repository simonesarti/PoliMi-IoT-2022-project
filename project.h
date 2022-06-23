#ifndef PROJECT_H
#define PROJECT_H

typedef enum {
	AM_MY_MSG = 6
}msg_enum;

typedef enum {
	PARENT = 0,
	CHILDREN = 1
}mote_type_t;


typedef enum{
	PAIRING = 0,
	PAIRING_RESP = 1,
	INFO = 2,
	ERROR = 999
}msg_type_t;

typedef enum{
	STANDING = 0,
	WALKING = 1,
	RUNNING = 2,
	FALLING = 3
}kinematic_status_t;

typedef struct info_msg_t{
	uint8_t senderID;
	uint16_t x;
	uint16_t y;
	kinematic_status_t kinematic_status;	
}info_msg_t;

typedef struct pairing_msg_t{
	uint8_t senderID;
	char key[20];	
}pairing_msg_t;

typedef struct pairing_resp_t{
	uint8_t responderID;
} pairing_resp_t;
 


#endif
