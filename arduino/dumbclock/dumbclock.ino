#include <Servo.h>
#include <WiFiNINA.h>
#include <WiFiHttpClient.h>

#include "arduino_secrets.h"

const char serverAddress[] = "atunnel.cf";
int port = 80;

WiFiClient client;
WiFiWebSocketClient wsClient(client, serverAddress, port);

Servo servo;

int count = 0;
char message[50];
const char spyOn[] = "milo";

void setup() {
  Serial.begin(9600);
  servo.attach(8);
  servo.write(0);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.print("Attempting to connect to Network named: ");
    Serial.println(SECRET_SSID);
    WiFi.begin(SECRET_SSID, SECRET_PASS);
    if (WiFi.status() != WL_CONNECTED) {
      delay(2000);
      return;
    } else {
      Serial.println("Connected");
    }
  }
  wsClient.begin();

  wsClient.beginMessage(TYPE_TEXT);
  wsClient.print(spyOn);
  wsClient.endMessage();

  Serial.print("-> ");
  Serial.println(spyOn);

  while (wsClient.connected()) {
    int messageSize = wsClient.parseMessage();

    if (messageSize > 0) {
      wsClient.read(message, messageSize);

      Serial.print("<- ");
      Serial.write(message, messageSize);
      Serial.println();

      if (strncmp(message, "homework", messageSize) == 0) {
        servo.write(180 - 22.5);
      } else if (strncmp(message, "procrastination", messageSize) == 0) {
        servo.write(90 - 22.5);
      } else if (strncmp(message, "entertainment", messageSize) == 0) {
        servo.write(22.5);
      } else if (strncmp(message, "unknown", messageSize) == 0) {
        servo.write(90 + 22.5);
      } else {
        servo.write(0);
      }
    }
  }
  Serial.println("-----------------");
}
