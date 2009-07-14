//
//  Start.m
//  OpenSludge
//
//	The startup-option window. (OS X version)
//
//  Created by Rikard Peterson on 2009-06-29.
//

#import "Start.h"
#include "Language.h"

extern settingsStruct gameSettings;

@interface SDLApplication : NSApplication
@end


@implementation StartController

- (id)init
{
	if (![super initWithWindowNibName:@"Startup"])
		return nil;
	
	return self;
}

// Load all the options, and check the boxes that reflect the current settings
- (void)windowDidLoad
{
	[fullScreenCheck setState:gameSettings.userFullScreen != 0];
	[languageList removeAllItems];
	if (gameSettings.numLanguages) {
		for (int i=0; i<= gameSettings.numLanguages; i++) {
			[languageList addItemWithTitle:[NSString stringWithFormat:@"Language %d", i]];			
		}
		[languageList selectItemAtIndex: gameSettings.languageID];
	} else {
		[languageList addItemWithTitle:@"No translations available"];			
		[languageList setEnabled:NO];
	}
}


-(IBAction)okButton:(id)sender
{
	gameSettings.userFullScreen = [fullScreenCheck state];
	if (gameSettings.numLanguages) {
		gameSettings.languageID = [languageList indexOfSelectedItem];
		if (gameSettings.languageID < 0) gameSettings.languageID = 0;
	}
	[[SDLApplication sharedApplication] stopModalWithCode:1];
	[self close];
}
-(IBAction)cancelButton:(id)sender
{
	[[SDLApplication sharedApplication] stopModalWithCode:0];
	[self close];
}

@end