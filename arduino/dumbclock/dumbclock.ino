#include <SPI.h>
#include <WiFiNINA.h>
#include <Servo.h>
#include "arduino_secrets.h"

WiFiClient client;
const char serverAddress[] = "192.168.16.149";
int port = 4444;

char message[128];
int index = 0;

Servo servo;

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
  if (!client.connected()) {
    client.connect(serverAddress, port);
    Serial.print("Connected to IP: ");
    Serial.println(serverAddress);
    client.println("arduino");
  }

  // if there's anything incoming, print it:
  while (client.available()) {
    char c = client.read();
    message[index++] = c;
    if(c == '\n') {
      Serial.write(message, index);
      if (strncmp(message, "wow", min(3,index))){
        servo.write(180);
      } else {
        servo.write(0);
      }
      index = 0;
      break;
    }
  }
}
