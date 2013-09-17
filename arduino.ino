/*-
 * Arduindow - Opens and closes the windows in your house
 * using an Arduino and open weather data.
 *
 * Team:
 *     Erica Raviola (iOS)
 *     Flavio Giobergia (APIs)
 *     Roberto Gambotto (Arduino)
 *     Simone Basso (sandwiches)
 *
 * Homepage: <https://github.com/bassosimone/arduindow>.
 *
 * See LICENSE for license conditions.
 */

#include <SPI.h>
#include <Ethernet.h>
#include <Servo.h> 

/////////////////////////////////////////
// BEGIN USER SETTINGS
/////////////////////////////////////////

//
// Server
//
//char server[] = "www.mysite.com";
IPAddress server(192, 168, 0, 1);

//
// Arduino
//
IPAddress ip(192, 168, 0, 2);
IPAddress submask(255, 255, 255, 0);
IPAddress gateway(192, 168, 0, 1);

//
// The HTTP request that we will send to the server
//
char http_request[] = "GET /arduindow/1.0/stats/open_close_window HTTP/1.0";

//
// The delay between two requests of update
//
const int REQUEST_DELAY = 5000;

//
// The MAC address of the Ethernet-Shield
//
byte mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };

//
// Boolean. If false (0) Arduino wont print informations on serial port
//
const int SERIAL_PRINT = 1;

//
// Servo config
//
const int CLOSE = 2;
const int OPEN = 135;

/////////////////////////////////////////
// END USER SETTINGS
/////////////////////////////////////////

const int DIM_BUFFER = 1000;

EthernetClient client;
Servo myServo;

char buffer[DIM_BUFFER + 1];
int n = 0,
    dim,
    read_value;

//
// Define the Arduino's pins
//
const int led = 3,
          servo = 5;

void setup()
{
  pinMode(led, OUTPUT);
  myServo.attach(servo);
  myServo.write(CLOSE);

  if(SERIAL_PRINT)
  {
    Serial.begin(9600);
    Serial.print("Starting serial monitor...\n");
  }

  Ethernet.begin(mac, ip, gateway, submask);

  //
  // Give three seconds to permit initialization of the ethernet-shield.
  // If you have connection problems, try with an higher delay.
  //
  delay(3000);
  if(SERIAL_PRINT)
    Serial.println("Connecting...\n");
}

void loop()
{
  digitalWrite(led, HIGH);

  if (client.connect(server, 80)) {
    if(SERIAL_PRINT)
      Serial.println("Connection accepted!\n");

    //
    // Send the request to the server
    //
    client.println(http_request);
    client.println();
    client.flush();

    //
    // Call the function that will read the answer
    //
    request();
  }
  else {
    if(SERIAL_PRINT)
      Serial.println("Connection failed!\n");
  }

  client.stop();

  delay(REQUEST_DELAY);
}

int request()
{
  int i = 0;
  char stringa[256];
  int go_on = 1;

  do {
    if (client.available()) {
      char c = client.read();
      if(SERIAL_PRINT)
        Serial.print(c);
      buffer[i] = c;
      i++;
      if(i >= DIM_BUFFER)
        go_on = 0;
    }

    // If the server closed the connection
    if (!client.connected()) {
      if(SERIAL_PRINT)
      {
        Serial.println();
        Serial.println("\n\nServer disconnected");
      }
      go_on = 0;
    }
  } 
  while(go_on);

  //
  // Don't bother checking, when the string we
  // read from the server is too short.
  //
  if (i < 13)
    return 1;

  dim = i;
  buffer[i] = '\0';
  i = 0;

  if (memcmp(buffer, "HTTP/1.1 200", 12))
    return 1;

  //
  // Quickly skip a the end of the request headers, by
  // looking for [\r\n]{4}. We assume that the server
  // is not using the non-standard LFLF terminator for
  // the headers, which is a sound assumption.
  //
  go_on = 1;
  n = 0;
  while (go_on) {
    if (buffer[i] == '\n' || buffer[i] == '\r')
      n++;
    else
      n = 0;
    if (n == 4 || i == DIM_BUFFER)
      go_on = 0;
    i++;
  }

  if (i > DIM_BUFFER - 1)
    return 1;

  read_value = 10 * (buffer[i] - '0') + (buffer[i + 1] - '0');

  if(SERIAL_PRINT)
  {
    snprintf(stringa, 100, "Value read: %d\n", read_value);
    Serial.print(stringa);
  }

  digitalWrite(led, LOW);
  read_value=(read_value*(OPEN-CLOSE)/100)+CLOSE;
  
  if(read_value >= CLOSE && read_value <= OPEN)
     set_servo(read_value);

  return 0;
}

void set_servo(int value)
{
  int pos = myServo.read();
  if(pos < value)
    while(pos < value)
    {
      myServo.write(++pos);
      delay(9);
    }
      
  if(pos > value)
    while(pos > value)
    {
      myServo.write(--pos);
      delay(9);
    }
}
