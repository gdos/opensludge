//
//  ProjectDocument.m
//  Sludge Dev Kit
//
//  Created by Rikard Peterson on 2009-07-18.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ProjectDocument.h"
#include "Project.hpp"

#include "settings.h"
#include "Interface.h"
#include "compilerinfo.h"

// -- These are from "MessBox.h"
struct errorLinkToFile
{
	int errorType;
	char * overview;
	char * filename;
	char * fullText;
	int lineNumber;
	struct errorLinkToFile * next;
};

extern char * errorTypeStrings[];


extern struct errorLinkToFile * errorList;
extern int numErrors;

// --

ProjectDocument * me;
NSModalSession session = nil;

@implementation ProjectDocument

- (id)init
{
    self = [super init];
    if (self) {	
		numResources = 0;		
    }
    return self;
}


- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"ProjectDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	
	[resourceFiles setDoubleAction:@selector(openItem:)];
	[resourceFiles setTarget:self];
	[projectFiles setDoubleAction:@selector(openProjectFile:)];
	[projectFiles setTarget:self];
	[compilerErrors setDoubleAction:@selector(openError:)];
	[compilerErrors setTarget:self];
	
	UInt8 project[1024];
	if (! CFURLGetFileSystemRepresentation((CFURLRef) [self fileURL], true, project, 1023))
		return;
	getSourceDirFromName ((char *) project);
}	

- (BOOL)readFromURL:(NSURL *)absoluteURL 
			 ofType:(NSString *)typeName 
			  error:(NSError **)outError
{
	if ([typeName isEqualToString:@"SLUDGE Project file"]) {	
		UInt8 buffer[1024];
		if (CFURLGetFileSystemRepresentation((CFURLRef) absoluteURL, true, buffer, 1023)) {
			if (loadProject ((char *) buffer, fileList, &fileListNum)) {
				[projectFiles noteNumberOfRowsChanged];
				return YES;
			}
		}
	} 
	*outError = [NSError errorWithDomain:@"Error" code:1 userInfo:nil];
	return NO;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL 
			ofType:(NSString *)typeName 
			 error:(NSError **)outError
{
	if ([typeName isEqualToString:@"SLUDGE Project file"]) {	
		UInt8 buffer[1024];
		if (CFURLGetFileSystemRepresentation((CFURLRef) absoluteURL, true, buffer, 1023)) {
			if (saveProject ((char *) buffer, fileList, &fileListNum)) {
				return YES;
			}
		}
	} 
	*outError = [NSError errorWithDomain:@"Error" code:1 userInfo:nil];
	return NO;
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == projectFiles) {
		if ([projectFiles numberOfSelectedRows]) {
			[removeFileButton setEnabled:YES];
			clearFileList (resourceList, &numResources);
			UInt8 project[1024];
			if (! CFURLGetFileSystemRepresentation((CFURLRef) [self fileURL], true, project, 1023))
				return;
			getSourceDirFromName ((char *) project);

			int i;
			for (i = 0; i < fileListNum; i ++) {
				if (! [projectFiles isRowSelected:i]) continue;
								
				populateResourceList (fileList[i], resourceList, &numResources);
			}
			[resourceFiles noteNumberOfRowsChanged];
		} else {
			clearFileList (resourceList, &numResources);
			[resourceFiles noteNumberOfRowsChanged];
			[removeFileButton setEnabled:NO];
		}
	}
}

- (void)openProjectFile:(id)sender
{
	int row = [projectFiles clickedRow];
	if (row == -1) 
		return;
	
	char *file = getFullPath (fileList[row]);
	[[NSWorkspace sharedWorkspace] openFile: [NSString stringWithUTF8String:file]];
	deleteString (file);
}

- (void)openError:(id)sender
{
	int row = [compilerErrors clickedRow];
	if (row == -1) 
		return;
	
	struct errorLinkToFile * index = errorList;
	if (! index) return;
	int i = numErrors-1;
	while (i>row) {
		if (! (index = index->next)) return;
		i--;
	}

	if (! index-> filename) {
		errorBox (errorTypeStrings[index->errorType], index->overview);
		return;
	}
	char *file = getFullPath (index->filename);
	[[NSWorkspace sharedWorkspace] openFile: [NSString stringWithUTF8String:file]];
	deleteString (file);
	//if (index->lineNumber) 
}

- (void)openItem:(id)sender
{
	int row = [resourceFiles clickedRow];
	if (row == -1) 
		return;
	
	char *file = getFullPath (resourceList[row]);
	[[NSWorkspace sharedWorkspace] openFile: [NSString stringWithUTF8String:file]];
	deleteString (file);
}

// This is the project file list!
- (int)numberOfRowsInTableView:(NSTableView *)tv
{
	if (tv == compilerErrors)
		return numErrors;
	else if (tv == projectFiles)
		return fileListNum; 
	else 
		return numResources;
}
- (id)tableView:(NSTableView *)tv
	objectValueForTableColumn:(NSTableColumn *)tableColumn
						  row:(int)row
{
	NSString *v;
	if (tv == compilerErrors) {
		struct errorLinkToFile * index = errorList;
		if (! index) return nil;
		int i = numErrors-1;
		while (i>row) {
			if (! (index = index->next)) return nil;
			i--;
		}
		v = [NSString stringWithUTF8String:index->fullText];
	} else if (tv == projectFiles) {
		if (row >= fileListNum) return nil;
		v = [NSString stringWithUTF8String:fileList[row]];
	} else {
		v = [NSString stringWithUTF8String:resourceList[row]];
	}
	return v;
}

- (IBAction)addFileToProject:(id)sender
{
	NSString *path = nil;
	NSOpenPanel *openPanel = [ NSOpenPanel openPanel ];
	[openPanel setTitle:@"Add file to SLUDGE Project"];
	NSArray *files = [NSArray arrayWithObjects:@"slu", @"sld", @"tra", nil];
	
	if ( [ openPanel runModalForDirectory:nil file:nil types:files] ) {
		path = [ openPanel filename ];
		UInt8 project[1024];
		if (! CFURLGetFileSystemRepresentation((CFURLRef) [self fileURL], true, project, 1023))
			return;
		getSourceDirFromName ((char *) project);
		addFileToProject ([path UTF8String], sourceDirectory, fileList, &fileListNum);
		
		[projectFiles noteNumberOfRowsChanged];
		[self updateChangeCount: NSChangeDone];
	}
}
- (IBAction)removeFileFromProject:(id)sender{
	if ([projectFiles numberOfSelectedRows]) {
		if (! NSRunAlertPanel (@"Remove files?", @"Do you want to remove the selected files from the project? (They will not be deleted from the disk.)", @"Yes", @"No", NULL) == NSAlertDefaultReturn) {
			return;
		}
		int i, o, num = fileListNum;
		for (i = 0, o= 0; i < num; i ++, o++) {
			if (! [projectFiles isRowSelected:i]) continue;
			[projectFiles deselectRow:i];
			removeFileFromList (o, fileList, &fileListNum);
			o--;
		}
		
		[projectFiles noteNumberOfRowsChanged];
		[removeFileButton setEnabled:NO];
		[self updateChangeCount: NSChangeDone];
	}
}

- (void)close 
{
	closeProject (fileList, &fileListNum);
	[super close];
}

-(bool) compile
{
	bool val = false;
	int success = false;
	me = self;
	session = [NSApp beginModalSessionForWindow:compilerWindow];
	[closeCompilerButton setEnabled:NO];
	[runGameButton setEnabled:NO];
	[progress1 setMaxValue: 1];
	[progress2 setMaxValue: 1];
	[NSApp runModalSession:session];

	UInt8 buffer[1024];
	if (CFURLGetFileSystemRepresentation((CFURLRef) [self fileURL], true, buffer, 1023)) {
		success = compileEverything(buffer, fileList, &fileListNum, &receiveCompilerInfo);
		val = true;
	}
	[closeCompilerButton setEnabled:YES];
	[NSApp endModalSession:session];
	if (numErrors) {
		[compilerErrors noteNumberOfRowsChanged];
		[tabView selectTabViewItemAtIndex:1];
	} 
	if (success) {
		[runGameButton setEnabled:YES];
	}
	return val;
}

- (IBAction)closeCompilerBox:(id)sender
{
	[compilerWindow close];
}

extern char * gameFile;

- (IBAction)runGame:(id)sender
{
	// Run the game
	char *file = getFullPath (gameFile);
	[[NSWorkspace sharedWorkspace] openFile: [NSString stringWithUTF8String:file]];
	fprintf(stderr, "*%s* *%s*\n", settings.finalFile, file);
	deleteString (file);
}


- (bool)showProjectPrefs
{
	[prefQuit setStringValue:[NSString stringWithUTF8String: settings.quitMessage]];
	[prefIcon setStringValue:[NSString stringWithUTF8String: settings.customIcon]];
	[prefLogo setStringValue:[NSString stringWithUTF8String: settings.customLogo]];
	[prefData setStringValue:[NSString stringWithUTF8String: settings.runtimeDataFolder]];
	[prefFile setStringValue:[NSString stringWithUTF8String: settings.finalFile]];
	[prefName setStringValue:[NSString stringWithUTF8String: settings.windowName]];
	[prefLanguage setStringValue:[NSString stringWithUTF8String: settings.originalLanguage]];
	[prefHeight setIntValue:settings.screenHeight];
	[prefWidth setIntValue:settings.screenWidth];
	[prefSpeed setIntValue:settings.frameSpeed];
	[prefSilent setIntValue: settings.forceSilent];
	
	[NSApp beginSheet:projectPrefs
	   modalForWindow:[self windowForSheet]
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:NULL];
	return true;
}

- (IBAction)endProjectPrefs:(id)sender{
	killSettingsStrings();
	settings.quitMessage = newString ([[prefQuit stringValue] UTF8String]);
	settings.customIcon = newString ([[prefIcon stringValue] UTF8String]);
	settings.customLogo = newString ([[prefLogo stringValue] UTF8String]);
	settings.runtimeDataFolder = newString ([[prefData stringValue]UTF8String]);
	settings.finalFile = newString ([[prefFile stringValue]UTF8String]);
	settings.windowName = newString ([[prefName stringValue]UTF8String]);
	settings.originalLanguage = newString ([[prefLanguage stringValue]UTF8String]);
	settings.screenHeight = [prefHeight intValue];
	settings.screenWidth = [prefWidth intValue];
	settings.frameSpeed = [prefSpeed intValue];
	settings.forceSilent = [prefSilent intValue];	
	
	[NSApp endSheet:projectPrefs];
	[projectPrefs orderOut:sender];
	[self updateChangeCount: NSChangeDone];
}

- (void) setCompilerInfo(compilerInfo *info)
{
	if (info->progress1 > -1.)
		[progress1 setDoubleValue: info->progress1];
	if (info->progress2 > -1.)
		[progress2 setDoubleValue: info->progress2];
	if (info->task[0] != 0) {
		NSString *s = [NSString stringWithUTF8String: info->task];
		if (s)
			[compTask setStringValue:s];
	}
	if (info->file[0] != 0){
		NSString *s = [NSString stringWithUTF8String: info->file];
		if (s)
			[compFile setStringValue:s];
	}
	if (info->item[0] != 0){
		NSString *s = [NSString stringWithUTF8String: info->item];
		if (s)
			[compItem setStringValue:s];
	}
	if (info->funcs > -1) {
		[compFuncs setIntValue: info->funcs];
	}
	if (info->objs > -1) {
		[compObjs setIntValue: info->objs];
	}
	if (info->globs > -1) {
		[compGlobs setIntValue: info->globs];
	}
	if (info->strings > -1) {
		[compStrings setIntValue: info->strings];
	}
	if (info->resources > -1) {
		[compResources setIntValue: info->resources];
	}
	if (info->newComments) {
		[compilerErrors noteNumberOfRowsChanged];
		[tabView selectTabViewItemAtIndex:1];
	}
}

@end

void receiveCompilerInfo(compilerInfo *info){
	[me setCompilerInfo: info];

	delete info;
}
