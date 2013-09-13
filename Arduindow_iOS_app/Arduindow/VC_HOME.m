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
#import "ARDUINDOW_HEADER.h"
#import "AFHTTPClient.h"
#import "AFHTTPRequestOperation.h"




static const CGFloat KEYBOARD_ANIMATION_DURATION = 0.3;
static const CGFloat MINIMUM_SCROLL_FRACTION = 0.2;
static const CGFloat MAXIMUM_SCROLL_FRACTION = 0.8;
static const CGFloat PORTRAIT_KEYBOARD_HEIGHT = 216;
static const CGFloat LANDSCAPE_KEYBOARD_HEIGHT = 140;


struct AR_DATA adata;

@interface VC_HOME ()

@end

@implementation VC_HOME


#pragma mark -
#pragma mark init
//============================================================//
//====	VIEW DID LOAD										==//
//====	VIEW DID LOAD										==//
//============================================================//
- (void)viewDidLoad {

	[super viewDidLoad];			// super...


	[self drawView];				// alloc, init and presents all view's subviews...
	[self setDataOnScreen];			// read from my struct last data and present them...

	[self httpGetToServer];			// the first time it's called this, after it's called by the timer...

	
	self.refreshTimer=[NSTimer timerWithTimeInterval:TIME_REFRESH target:self selector:@selector(refreshButton) userInfo:nil repeats:YES];		// init the timer.
	[[NSRunLoop currentRunLoop] addTimer:self.refreshTimer forMode:NSRunLoopCommonModes];														// add the timer, it'll fire 10 sec after

}

//============================================================//
//============================================================//
//============================================================//
- (void)didReceiveMemoryWarning {

    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//=================================================================//
//===	VIEW DID DISAPPER...						===============//
//=================================================================//
-(void) viewDidDisappear:(BOOL)animated {

	[super viewDidDisappear:animated];


	[self.refreshTimer invalidate];			// stop timer.
	self.refreshTimer=nil;

	[self writeArduindowData];			// write configuration

}

#pragma mark -
#pragma mark startHttpGetRequest
//===========================================================================================//
//==	httpGetToServer:																  ===//
//==	httpGetToServer:																  ===//
//==	httpGetToServer:																  ===//
//===========================================================================================//
//== Start a http GET request and receive response (success or failure) 				  ===//
//== using blocks. For further documentation: https://github.com/AFNetworking/AFNetworking ==//
//===========================================================================================//
- (int) httpGetToServer {
int err=0;

	//-------------------------------------------------------------------//
	//-----	PREPARE HTTP REQUEST...								---------//
	//-------------------------------------------------------------------//
	NSString *serverAddr=[NSString stringWithCString:adata.serverAddress encoding:NSUTF8StringEncoding];		// e.g. http://www.ifisica.net46.net/index.php

	if([serverAddr length]<4) {					// if it's too short...
		printf("server Address error...\n");
		return -1;
	}
	NSURL *url=[NSURL URLWithString:serverAddr];
	AFHTTPClient *httpClient = [[AFHTTPClient alloc] initWithBaseURL:[url URLByDeletingLastPathComponent]];		// delete index.php...
	httpClient.parameterEncoding = AFFormURLParameterEncoding;
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"?", @"v", nil];							// value of GET request..
	NSMutableURLRequest *request = [httpClient requestWithMethod:@"GET" path:serverAddr parameters:params];		// set up request

	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	[httpClient registerHTTPOperationClass:[AFHTTPRequestOperation class]];

	//-------------------------------------------------------------------//
	//-----		SUCCESS BLOCK...								---------//
	//-------------------------------------------------------------------//
	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {

		NSData *data=(NSData *) responseObject;
		NSString *str2=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];			// use UTF8 or ASCII to convert data in string...

		//NSLog(@"str2=%@", str2);

		if(![str2 length])	return;						// if the string is empty...

		//------ It's expected a JSON file, but sometimes (especially if the server is on a web host) I could receive server messages,
		//------ starting with "<h"...
		NSRange rg=[str2 rangeOfString:@"<h"];
		if(rg.length) {
			NSLog(@"ERROR FORMAT...");
			return;
		}

		//------- Finding the substring containing the JSON file... maybe after JSON file there is something else... --------//
		int i;
		for(i=0;i<[str2 length]; i++) {
			if([str2 characterAtIndex:i]=='}')  break;
		}

		//-------- extracts from str2 (JSON file) a NSDictionary...	-------//
		NSMutableDictionary *dicJSON=[NSJSONSerialization JSONObjectWithData:[[str2 substringWithRange:NSMakeRange(0, i+1)] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

		if(dicJSON) {
			NSDate *now=[NSDate date];							// save last successfully refresh time...
			adata.phpTimeUpdate=[now timeIntervalSince1970];

			[self readJson:dicJSON];							// read data from JSON-NSDictionary and saved them in our structure...

			[self setDataOnScreen];								// refresh information on screen...
			
			
		}
	//-------------------------------------------------------------------//
	//-----		FAILURE BLOCK...								---------//
	//-------------------------------------------------------------------//
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		NSLog(@"Error: %@", error);

	}];

	[operation start];

	return err;

}


//===========================================================//
//== touch up on refresh button						=========//
//===========================================================//
-(void) refreshButton {

	[self httpGetToServer];

}


#pragma mark -
#pragma mark readAndWritingFiles
//===============================================================//
//===	Read Json file (already in a NSDictionary) and saved   ==//
//===   some info in app's data...								=//
//===============================================================//
-(void) readJson:(NSMutableDictionary *) data {

	strcpy(adata.meteoStation, [[data valueForKey:@"meteo_station"] cStringUsingEncoding:NSUTF8StringEncoding]);	// name of meteo station...

	NSString *str=[data valueForKey:@"date_fancy"];
	str=[str stringByAppendingString:@" GMT"];			// append GMT
	strcpy(adata.arpaTimeUpdate, [str cStringUsingEncoding:NSUTF8StringEncoding]);		// date of last ARPA refresh as C string

	adata.celsiusTemperature=[[data valueForKey:@"temperature_celsius"] floatValue];			// temperature (in celsius)
	adata.precipitDay=[[data valueForKey:@"precip_day"] floatValue];							// mm of rain

	NSString *str2=[data valueForKey:@"window_status"];
	if([str2 isEqualToString:@"close"])   adata.windowStatus=0;  else  adata.windowStatus=1;


}

//==============================================================//
//===	Read binary file with Arduindow app's configuration	====//
//===   Return 0 if the file's size is correct, != 0 if it's ===//
//===   wrong.												 ===//
//==============================================================//
-(int) readArduindowData {
int ris;

	NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);		// access to our file.. 
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *file = [documentsDirectory stringByAppendingPathComponent: DATA_FNAME];
	NSData *read = [NSData dataWithContentsOfFile:file];
	ris=0;
	if([read length]!=sizeof(adata)) {								// if file's size is not equal to ADATA's size...
		NSLog(@"Error during reading configuration file...\n");
		ris++;
	} else {
		[read getBytes:&adata length:sizeof(adata)];				// copy file content in ADATA...
		NSLog(@"Binary Arduindow file read correct...\n");
	}

	return ris;

}

//==============================================================//
//===	WRITE binary file with Arduindow app's configuration  ==//
//===   Return 0 -> no error, != 0 if something wrong happened ==//
//==============================================================//
-(int) writeArduindowData {
int ris;
	
	NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);		// access to our file
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *file = [documentsDirectory stringByAppendingPathComponent: DATA_FNAME];				// if the file is not present, it creates one.

	NSData *nsdata=[NSData dataWithBytes:&adata length:sizeof(adata)];								// create a NSdata object with struct adata.

	ris=[nsdata writeToFile:file atomically:YES];													// write nsdata to binary file.

	if(ris) printf("Write data is ok... \n");	else return -1;
	return 0;
	
}




#pragma mark -
#pragma mark textFieldDelegate
//================================================================================
//====	Method for UItextfield delegate.										==
//====  Hide the keyboard when user taps "enter".								==
//================================================================================
-(BOOL) textFieldShouldReturn : (UITextField *) textField {

	[tfServer resignFirstResponder];
	return YES;
}


//====================================================================================
//====  Method for UItextField delegate.											==
//====  delegate is notified when user start editing the server address text field. ==
//====  Because this text field is at the bottom of our view, move a little high    ==
//====  the text field.																==
//====================================================================================
- (void)textFieldDidBeginEditing:(UITextField *)textField {

   	CGRect textFieldRect = [self.view.window convertRect:textField.bounds fromView:textField];
	CGRect viewRect = [self.view.window convertRect:self.view.bounds fromView:self.view];

    CGFloat midline = textFieldRect.origin.y + 0.5 * textFieldRect.size.height;
    CGFloat numerator =
            midline - viewRect.origin.y - MINIMUM_SCROLL_FRACTION * viewRect.size.height;
    CGFloat denominator =
            (MAXIMUM_SCROLL_FRACTION - MINIMUM_SCROLL_FRACTION) * viewRect.size.height;
    CGFloat heightFraction = numerator / denominator;

   if (heightFraction < 0.0) {
        heightFraction = 0.0;
    }
    else if (heightFraction > 1.0) {
        heightFraction = 1.0;
    }

   UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        animatedDistance = floor(PORTRAIT_KEYBOARD_HEIGHT * heightFraction);
    } else {
        animatedDistance = floor(LANDSCAPE_KEYBOARD_HEIGHT * heightFraction);
    }

   if (heightFraction < 0.0) {
        heightFraction = 0.0;
    } else if (heightFraction > 1.0) {
        heightFraction = 1.0;
    }

    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        animatedDistance = floor(PORTRAIT_KEYBOARD_HEIGHT * heightFraction);
    } else {
        animatedDistance = floor(LANDSCAPE_KEYBOARD_HEIGHT * heightFraction);
    }

   	CGRect viewFrame = self.view.frame;
    viewFrame.origin.y -= animatedDistance;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:KEYBOARD_ANIMATION_DURATION];

    [self.view setFrame:viewFrame];

    [UIView commitAnimations];

	
}


//====================================================================================
//====  Method for UItextField delegate.											==
//====  delegate is notified when user stop  editing the server address text field. ==
//====================================================================================
//====================================================================================
- (void)textFieldDidEndEditing:(UITextField *)textField {


	//-----------  Put back the view...			----------------------//
    CGRect viewFrame = self.view.frame;
    viewFrame.origin.y += animatedDistance;

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:KEYBOARD_ANIMATION_DURATION];

    [self.view setFrame:viewFrame];
    [UIView commitAnimations];

	//--------- Hide keyboard...			------------------------//
	[tfServer resignFirstResponder];


	//-------- Save new address...			------------------------//
	NSString *str=[NSString stringWithString:tfServer.text];
	str=[str stringByReplacingOccurrencesOfString:@"\n" withString:@""];			// user may tap "\n" for stop editing, we have to delete this character.
	strcpy(adata.serverAddress, [str cStringUsingEncoding:NSUTF8StringEncoding]);	// save new server address..
	[self httpGetToServer];															// send a GET request to server

}


#pragma mark -
#pragma mark userInterfaceDrawing
//====================================================================================//
//== Added all the objects on self.view by code....									==//
//== Added all the objects on self.view by code....									==//
//====================================================================================//
-(void) drawView {
int coordY, coordX, spaziat, sideImg, idx, bb;
float barHeight;

	barHeight=40;
	spaziat=10;
	sideImg=65;
	coordY=0;
	coordX=spaziat;

	//----------------- black bar at the top of the view...			--------------//
	UIImageView *bar=[[UIImageView alloc]initWithFrame:CGRectMake(0, 0, WIDTH_SCREEN, barHeight)];
	[bar setImage:[UIImage imageNamed:@"BAR.png"]];
	[self.view addSubview:bar];

	//---------------- just allocate the UILabel objects (we cannot put in a NSArray nil object)... -----------//
	lbPrecipToday=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	lbWindow=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	lbStation=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	lbTemp=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	lbTimeArpa=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];

	//--------------- Set arrays used later													------------------//
	NSArray *textLabel1=[NSArray arrayWithObjects:@"Stazione meteo di:", @"Aggiornamento stazione:", @"Temperatura:", @"Precipitazioni:", @"Stato finestra:", nil];
	NSArray *textLabel2=[NSArray arrayWithObjects:@"..", @".", @".", @".", @".", nil];
	NSArray *imgs=[NSArray arrayWithObjects:@"I_HOME_2.png",@"I_CLOCK.png",@"I_TEMP.png",@"I_RAIN.png",@"I_SHUTTER.png", nil];
	NSArray *arrayLabels=[NSArray arrayWithObjects:lbStation, lbTimeArpa, lbTemp, lbPrecipToday, lbWindow, nil];


	//----------- Create the scroll where we'll put all the objects (expect the black bar).		-----------//
	UIScrollView *scroll=[[UIScrollView alloc]initWithFrame:CGRectMake(0, barHeight, WIDTH_SCREEN, HEIGHT_SCREEN)];
	[scroll setBackgroundColor:[UIColor lightGrayColor]];

	//--------------------------------------------------------------------------------//
	//---	Prepare objects where information taken from Json file are visible.	------//
	//--------------------------------------------------------------------------------//
	for(idx=0; idx<5; idx++) {

		coordY+=spaziat;

		//------------  GREY ICON on the left...		---------//
		//----------	These images are static.		---------//
		UIImageView *img1=[[UIImageView alloc] initWithFrame:CGRectMake(coordX, coordY,sideImg , sideImg)];
		[img1 setImage:[UIImage imageNamed:(NSString *)[imgs objectAtIndex:idx]]];
		[scroll addSubview:img1];

		//------------- First LABEL WITH DESCRIPTION...		-----------//
		//--- 			these labels are static.            -----------//
		UILabel *lbDesc=[[UILabel alloc] initWithFrame:CGRectMake(coordX+sideImg+(spaziat/2), coordY, 250, 35)];
		[lbDesc setText:(NSString *)[textLabel1 objectAtIndex:idx]];
		[lbDesc setFont:[UIFont italicSystemFontOfSize:16.0f]];
		[lbDesc setBackgroundColor:[UIColor clearColor]];
		[scroll addSubview:lbDesc];


		bb=25;
		if(idx>1)		bb=0;		// for the  last 3, lbVlue is on the same line of lbdesc
		//------------- Second LABEL WITH VALUE...		------------------------------------------------//
		//----- 		These labels' text change during the app runnig, so they're global variables. --// 
		UILabel *lbValue=(UILabel *)[arrayLabels objectAtIndex:idx];
		[lbValue setFrame:CGRectMake(coordX+sideImg, coordY+bb, WIDTH_SCREEN-2*spaziat-coordX-sideImg, 35)];
		[lbValue setTextAlignment:NSTextAlignmentRight];
		[lbValue setText:(NSString *)[textLabel2 objectAtIndex:idx]];
		[lbValue setFont:[UIFont boldSystemFontOfSize:17.5f]];
		[lbValue setBackgroundColor:[UIColor clearColor]];
		[scroll addSubview:lbValue];
		
		coordY+=sideImg;

	}

	coordY+=spaziat;

	//----------- Button for refresh...														-----------//
	UIButton *bt3=[[UIButton alloc] initWithFrame:CGRectMake(coordX, coordY, WIDTH_SCREEN-2*spaziat, 70)];
	[bt3 addTarget:self action:@selector(refreshButton) forControlEvents:UIControlEventTouchUpInside];
	[bt3 setTitle:@"AGGIORNA" forState:UIControlStateNormal];
	[bt3 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[bt3.titleLabel setFont:[UIFont boldSystemFontOfSize:25]];
	[bt3 setBackgroundImage:[UIImage imageNamed:@"RED_BUTTON.png"] forState:UIControlStateNormal];
	[scroll addSubview:bt3];

	//----------- Label with last time refresh with our server ..							-----------//
	coordY+=60;			coordY+=spaziat;
	lbTimeServer=[[UILabel alloc]initWithFrame:CGRectMake(coordX, coordY, WIDTH_SCREEN-2*spaziat, 25)];
	[lbTimeServer setBackgroundColor:[UIColor clearColor]];
	[lbTimeServer setFont:[UIFont italicSystemFontOfSize:17.0f]];
	[lbTimeServer setTextAlignment:NSTextAlignmentCenter];
	[scroll addSubview:lbTimeServer];
	coordY+=10;			coordY+=spaziat;

	//---------- Label for server address..															-----//
	UILabel *lbServer1=[[UILabel alloc] initWithFrame:CGRectMake(coordX, coordY, WIDTH_SCREEN-2*spaziat, 30)];
	[lbServer1 setBackgroundColor:[UIColor clearColor]];
	[lbServer1 setFont:[UIFont boldSystemFontOfSize:16.0f]];
	[lbServer1 setText:@"Indirizzo del server:"];
	[scroll addSubview:lbServer1];

	coordY+=40/2;		coordY+=spaziat;

	//--------- Text field where user can insert server address..					------------//
	tfServer=[[UITextField alloc]initWithFrame:CGRectMake(coordX, coordY, WIDTH_SCREEN-2*spaziat, 28)];
	[tfServer setBackgroundColor:[UIColor whiteColor]];
	[tfServer setBorderStyle:UITextBorderStyleRoundedRect];
	[tfServer setDelegate:self];
	[tfServer setText:[NSString stringWithCString:adata.serverAddress encoding:NSUTF8StringEncoding]];
	[scroll addSubview:tfServer];

	[scroll setContentSize:CGSizeMake(WIDTH_SCREEN, 640)];				// set the content size of the scroll.
	[self.view addSubview:scroll];										// add scroll to our view.
	[self.view setNeedsDisplay];										// refresh our view.

}



//========================================================//
//==  Set/refresh information on the view ================//
//========================================================//
-(void) setDataOnScreen {

	[lbStation setText:[NSString stringWithCString:adata.meteoStation encoding:NSUTF8StringEncoding]];
	[lbTimeArpa setText:[NSString stringWithCString:adata.arpaTimeUpdate encoding:NSUTF8StringEncoding]];
	
	[lbTemp setText:[NSString stringWithFormat:@"%.2f %cC", adata.celsiusTemperature, 188]];		// 188-> ∘
	[lbPrecipToday setText:[NSString stringWithFormat:@"%.1f mm", adata.precipitDay]];

	if(adata.windowStatus) {
		[lbWindow setText:@"APERTA"];
	} else {
		[lbWindow setText:@"CHIUSA"];
	}

	[lbTimeServer setText:[[NSDate dateWithTimeIntervalSince1970:adata.phpTimeUpdate] description]];
	[tfServer setText:[NSString stringWithCString:adata.serverAddress encoding:NSUTF8StringEncoding]];

}

//-----------------------------------------------------------------------------------//
//-----------------------------------------------------------------------------------//
//-----------------------------------------------------------------------------------//
//-----------------------------------------------------------------------------------//
//-----------------------------------------------------------------------------------//

@end
