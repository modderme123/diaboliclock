#include <IRremote.h>
#include <Stepper.h>

int IR_RECV_PIN = 12;

uint16_t back = 0x44;
uint16_t forward = 0x43;
int motor_displacement = 0;

int STEPS = 64;
Stepper stepper(STEPS, 3, 5, 4, 6);

void setup() {
  stepper.setSpeed(40);
  Serial.begin(9600);
  IrReceiver.begin(IR_RECV_PIN, ENABLE_LED_FEEDBACK);
}

void loop() {
  if (IrReceiver.decode()) {
    uint16_t value = IrReceiver.decodedIRData.command;

    if (value == back) {
      motor_displacement = -1;
    } else if (value == forward) {
      motor_displacement = 1;
    }

    IrReceiver.resume();
  }
  stepper.step(motor_displacement);
}
