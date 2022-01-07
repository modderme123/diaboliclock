/*#include <IRremote.h>
#include <Stepper.h>

int RECV_PIN = 2;
IRrecv irrecv(RECV_PIN);
decode_results results;

int back = 8925;
int forward = -15811;
int motor_angle = 0;
int motor_displacement = 0;

int STEPS = 64;
Stepper stepper(STEPS, 3, 4, 5, 6);

void setup() {
  // put your setup code here, to run once:
  stepper.setSpeed(60);
  Serial.begin(9600);
  irrecv.enableIRIn();
}

void loop() {
  // put your main code here, to run repeatedly:
  int value = irrecv.decode();
  if (value != 0) {   // Results of decoding are stored in result.value     
    Serial.println(" ");     
    Serial.print("commanded angle: ");     
    Serial.println(motor_angle); //prints the value a a button press
    Serial.println(value);   
    
    if (value == back) {
      motor_displacement = -30;
    } else if (value == forward) {
      motor_displacement = 30;
    }
    motor_angle += motor_displacement;
    stepper.step(STEPS * motor_displacement);

    irrecv.resume();
  }
}

#include <IRremote.hpp>

void setup()
{
  // stepper.setSpeed(60);
  Serial.begin(9600);
  IrReceiver.begin(2, ENABLE_LED_FEEDBACK); // Start the receiver
}

void loop() {
  if (IrReceiver.decode()) {
      (IrReceiver.decodedIRData.decodedRawData, HEX);
      Serial.println(value, HEX);

      
      IrReceiver.resume(); // Enable receiving of the next value
  }
}
*/

#include <Stepper.h>

const int stepsPerRevolution = 64;  // change this to fit the number of steps per revolution
// for your motor

// initialize the stepper library on pins 8 through 11:
Stepper myStepper(stepsPerRevolution, 3, 4, 5, 6);

void setup() {
  // set the speed at 60 rpm:
  myStepper.setSpeed(60);
  // initialize the serial port:
  Serial.begin(9600);
}

void loop() {
  // step one revolution  in one direction:
  Serial.println("clockwise");
  myStepper.step(stepsPerRevolution);
  delay(500);

  // step one revolution in the other direction:
  Serial.println("counterclockwise");
  myStepper.step(-stepsPerRevolution);
  delay(500);
}
