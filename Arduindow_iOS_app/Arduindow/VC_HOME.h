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

#import <UIKit/UIKit.h>

@interface VC_HOME : UIViewController <UITextFieldDelegate> {

	//------------- subviews of self.view...	-----------------//
	UILabel 	*lbStation;
	UILabel 	*lbTimeArpa;
	UILabel 	*lbTemp;
	UILabel 	*lbPrecipToday;
	UILabel 	*lbWindow;
	UILabel 	*lbTimeServer;
	UITextField *tfInform;
	UITextField	*tfServer;

	float animatedDistance;				// used for scrolling the view when start text field editing

	//NSTimer		*refreshTimer;			// used for send a get request to our server...
}

@property NSTimer *refreshTimer;


//------------- Methods visible from other classes (e.g. AppDelegate) -------------------//
-(int) writeArduindowData;
-(int) readArduindowData;

@end
