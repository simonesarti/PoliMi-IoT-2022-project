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



typedef nx_struct my_msg_t{
	nx_uint8_t msg_type;
	nx_uint8_t senderID;
	nx_uint8_t key[21];	
	nx_uint16_t x;
	nx_uint16_t y;
	nx_uint8_t kinematic_status;
}my_msg_t;


typedef struct info_data {
  uint16_t x;
  uint16_t y;
  uint16_t kinematic_status ;
} info_data;


#endif
