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
	INFO = 2
}msg_type_t;

typedef enum{
	NONE = 0,
	STANDING = 1,
	WALKING = 2,
	RUNNING = 3,
	FALLING = 4
}kinematic_status_t;



typedef struct my_msg_t{
	msg_type_t msg_type;
	uint8_t senderID;
	char key[20];	
	uint16_t x;
	uint16_t y;
	kinematic_status_t kinematic_status;
}my_msg_t;
 


#endif
