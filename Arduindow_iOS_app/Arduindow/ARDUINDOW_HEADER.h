//
//	Arduindow
//	Project for the first Turin OpenData Hackathon.
//	Opens and closes the windows in your house using an Arduino and open weather data.
//
//	Team:
//	Flavio Giobergia (APIs)
//	Roberto Gambotto (Arduino)
//	Erica Raviola (iOS)
//	Simone Basso (sandwiches)
//

#import "VC_HOME.h"
#ifndef Arduindow_ARDUINDOW_HEADER_h
#define Arduindow_ARDUINDOW_HEADER_h


//=================================================================================//
//====	GLOBAL DEFINE...														===//
//====	GLOBAL DEFINE...														===//
//====	GLOBAL DEFINE...														===//
//=================================================================================//
#define CLEAROBJ(data) 		memset(&data,0,sizeof(data))						// clear stru or array or union
#define WIDTH_SCREEN		320													//
#define HEIGHT_SCREEN		[[UIScreen mainScreen] bounds].size.height			// it may change (4 or 5)
#define DATA_FNAME			@"arduindow.cfg"									// name of binary file where configuration is written
#define TIME_REFRESH		30.0f												// express in seconds, every 5 seconds we send a get request to our server. 

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//++	STRUCT USED FOR SAVING DATA....													 +++//
//++	STRUCT USED FOR SAVING DATA....													 +++//
//++	STRUCT USED FOR SAVING DATA....													 +++//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
struct AR_DATA {

	char 					serverAddress[512];
	char 					meteoStation[256];
	float					precipitDay;			// in mm
	float					precipitDelta;			// in mm
	float					celsiusTemperature;
	char  					arpaTimeUpdate[64];		// last data update on ARPA server.
	unsigned long long  	phpTimeUpdate;			// seconds from last successfully connection to our server (express in seconds from time1970).
	int 					windowStatus;			// if ==0 -> window close, if >0 -> window open.

};

extern struct AR_DATA adata;



#endif
