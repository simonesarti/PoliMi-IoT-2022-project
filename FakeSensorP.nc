/**
 *  Source file for implementation of module Middleware
 *  which provides the main logic for middleware message management
 *
 *  @author Luca Pietro Borsani
 */
 
generic module FakeSensorP() {

	provides interface Read<info_data_t>;
	
	uses interface Random;
	uses interface Timer<TMilli> as Timer0;

} implementation {

	//***************** Boot interface ********************//
	command error_t Read.read(){
		call Timer0.startOneShot( 10 );
		return SUCCESS;
	}

	//***************** Timer0 interface ********************//
	event void Timer0.fired() {
		
		info_data_t data;
	  	data.x = call Random.rand16();
	  	data.y = call Random.rand16();
	  	data.kinematic_status = call Random.rand16();
	  	signal Read.readDone( SUCCESS, data);
	}
}
