#include <Servo.h>
#include <WiFiNINA.h>
#include <WiFiHttpClient.h>

#include "arduino_secrets.h"

const char serverAddress[] = "atunnel.cf";
int port = 80;

WiFiClient           client;
WiFiWebSocketClient  wsClient(client, serverAddress, port);

Servo servo;

int count = 0;

void setup() {
  Serial.begin(9600);
  servo.attach(8);

  while (true) {
    Serial.print("Attempting to connect to Network named: ");
    Serial.println(SECRET_SSID);
    WiFi.begin(SECRET_SSID, SECRET_PASS);
    if (WiFi.status() != WL_CONNECTED) {
      delay(2000);
    } else {
      break;
    }
  }

  // When you're connected, print out the device's network status:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);
}

void loop() {
  Serial.println("Connecting...");
  wsClient.begin();

  wsClient.beginMessage(TYPE_TEXT);
  wsClient.print("arduino");
  wsClient.endMessage();

  Serial.println("Connected");

  while (wsClient.connected()) {
    int messageSize = wsClient.parseMessage();

    if (messageSize > 0) {
      String message = wsClient.readString();

      Serial.print("Received a message: ");
      Serial.println(message);

      if(message ==  "homework") {
        servo.write(180);
      } else if(message ==  "procrastination") {
        servo.write(60);
      } else if(message ==  "entertainment") {
        servo.write(0);
      } else { //message == "unknown"
        servo.write(120);
      }
    }
  }
}
