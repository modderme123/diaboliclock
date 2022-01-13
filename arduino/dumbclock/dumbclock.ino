#include <SPI.h>
#include <WiFiNINA.h>
#include <Servo.h>
#include <WiFiHttpClient.h>

#include "arduino_secrets.h"

const char serverAddress[] = "192.168.16.149";
int port = 4444;

WiFiClient           client;
WiFiWebSocketClient  wsClient(client, serverAddress, port);

Servo servo;

int count = 0;

void setup() {
  Serial.begin(9600);
  servo.attach(8);

  while (WiFi.status() != WL_CONNECTED) {
    Serial.print("Attempting to connect to Network named: ");
    Serial.println(SECRET_SSID);
    WiFi.begin(SECRET_SSID, SECRET_PASS);
    delay(2000);
  }

  // When you're connected, print out the device's network status:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);
}

void loop() {
  Serial.print("Connecting...");
  wsClient.begin();

    wsClient.beginMessage(TYPE_TEXT);

  wsClient.print("arduino");
    wsClient.endMessage();

  Serial.print("Sent Hello");

  while (wsClient.connected()) {
    int messageSize = wsClient.parseMessage();

    if (messageSize > 0) {
      Serial.println("Received a message:");
      String message = wsClient.readString();
      if(message ==  "wow") {
        servo.write(180);
      } else {
        servo.write(0);
      }
      Serial.println();
    }

  }
}
