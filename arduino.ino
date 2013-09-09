/*
Arduindow
Project for the first Turin OpenData Hackathon. 
Opens and closes the windows in your house using an Arduino and open weather data.

Team:
Erica Raviola (iOS)
Flavio Giobergia (APIs)
Roberto Gambotto (Arduino)
Simone Basso (sandwiches)
*/

#include <SPI.h>
#include <Ethernet.h>

/////////////////////////////////////////
//USER SETTINGS
//You should set those settings with your client/server information, before doing any other things.
/////////////////////////////////////////

//char server[] = "www.mysite.com"; //The URL where A. will get the weather data
IPAddress server(192,168,0,1); //Otherwise, you could simply use the server IP address; this way give you a bit quicker connection.

IPAddress ip(192,168,0,2); //Arduino's IP address
IPAddress submask(255,255,255,0); //Arduino's Subnet Mask
IPAddress gateway(192,168,0,1); //Arduino's Gateway

char richiesta[]="GET /arduindow/1.0/stats/open_close_window HTTP/1.0"; //The request that A. will send to the server

const int REQUEST_DELAY=5000; //The delay between two requests of update

/////////////////////////////////////////
//END USER SETTINGS
/////////////////////////////////////////

const int DIM_BUFFER=1000;

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED }; //MAC address of Ethernet-Shield

EthernetClient client;

char buffer[DIM_BUFFER+1];
int n=0,
    dim,
    valore_letto;

const int led=3, motore=5; //Define A. pins

void setup() {
  
  pinMode(led, OUTPUT); 
  pinMode(motore, OUTPUT); 
  
  Serial.begin(9600);
  Serial.print("Starting serial monitor...\n");

  Ethernet.begin(mac, ip, gateway, submask);
 
  //Give three seconds to permit initialization of ethernet-shiled
  //If you have some connection problems, try to put an higher delay
  delay(3000);
  Serial.println("Connecting...\n");
}

void loop()
{
  digitalWrite(led, 170);
  if (client.connect(server, 80)) {
    Serial.println("Connection accepted!\n");
    
    client.println(richiesta); //Send the request to the server
    client.println();
    client.flush();
    
    request(); //Call the function that will read the answer 
  } 
  else {
    Serial.println("Connection failed!\n");
  }
  
  client.stop();
  
  delay(REQUEST_DELAY);
}

int request()
{
  int i=0;
  char stringa[256];
  int continua=1;
  
  do{
    if (client.available())
    {
      char c = client.read();
      Serial.print(c);
      buffer[i]=c;
      i++;
      if(i>=DIM_BUFFER)
        continua=0;
    }

    //If the server close the connection
    if (!client.connected())
    {
      Serial.println();
      Serial.println("\n\nServer disconnected");
      continua=0;
    }
    //-----------------
  }while(continua);
  
  if(i<13)
    return 1;
  dim=i;
  buffer[i]='\0';
  i=0;
  
  if(memcmp(buffer, "HTTP/1.1 200", 12))
    return 1;
 
  continua=1;
  n=0;
  while(continua)
  {
    if(buffer[i]=='\n' || buffer[i]=='\r')
      n++;
    else
      n=0;
    if(n==4 || i==DIM_BUFFER)
      continua=0;
    i++;
  }
  
  valore_letto=10*(buffer[i]-'0')+(buffer[i+1]-'0');
  
  sprintf(stringa, "Value read: %d\n", valore_letto);
  Serial.print(stringa);
  
  digitalWrite(led, LOW);
  analogWrite(motore, valore_letto*2.55);
  
  return 0;
}
