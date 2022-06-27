#include "project.h"
        //#include "project_serial.h"

configuration projectAppC {}

implementation {

  /****** COMPONENTS *****/
  components MainC, projectC as App;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  
  components new TimerMilliC() as Pairing_Timer;
  components new TimerMilliC() as Info_Timer;
  components new TimerMilliC() as OutOfRange_Timer;

  components new FakeSensorC();

  components ActiveMessageC;
  //components SerialActiveMessageC;
  
  /****** INTERFACES *****/
  App.Boot -> MainC.Boot;
  
  //Send and Receive interfaces
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;
  App.PacketAcknowledgements -> AMSenderC.Acks; //ActiveMessageC
  
  //Radio Control
  App.SplitControl -> ActiveMessageC;
  
  //Timer interface
  App.Pairing_Timer -> Pairing_Timer;
  App.Info_Timer -> Info_Timer;
  App.OutOfRange_Timer -> OutOfRange_Timer;
  
  //Interfaces to access package fields
  App.Packet -> AMSenderC;
  
  //Fake Sensor read
  App.FakeSensor -> FakeSensorC;

  // Serial port components
  //App.SerialControl -> SerialActiveMessageC;
  //App.SerialAMSend -> SerialActiveMessageC.AMSend[AM_MY_MSG];
  //App.SerialPacket -> SerialActiveMessageC;



}

