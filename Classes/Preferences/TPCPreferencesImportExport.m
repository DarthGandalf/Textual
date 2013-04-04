/* *********************************************************************
 _____        _               _    ___ ____   ____
 |_   _|___  _| |_ _   _  __ _| |  |_ _|  _ \ / ___|
 | |/ _ \ \/ / __| | | |/ _` | |   | || |_) | |
 | |  __/>  <| |_| |_| | (_| | |   | ||  _ <| |___
 |_|\___/_/\_\\__|\__,_|\__,_|_|  |___|_| \_\\____|

 Copyright (c) 2010 — 2013 Codeux Software & respective contributors.
 Please see Contributors.pdf and Acknowledgements.pdf

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the Textual IRC Client & Codeux Software nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import "TextualApplication.h"

/*
	Everything related to import/export is handled within this class. This class
	should only be called by awakeFromNib in master controller and the associated
	menu items in the menu controller.

	Sheets are used to lock focus to the task at hand.
 */

@implementation TPCPreferencesImportExport

/* -import handles the actual import menu item. */
+ (void)import
{
	TLOPopupPrompts *prompt = [TLOPopupPrompts new];

	[prompt sheetWindowWithQuestion:self.masterController.mainWindow
							 target:self
							 action:@selector(importPreflight:)
							   body:TXTLS(@"PreferencesImportPreflightDialogMessage")
							  title:TXTLS(@"PreferencesImportPreflightDialogTitle")
					  defaultButton:TXTLS(@"PreferencesImportPreflightDialogSelectFileButton")
					alternateButton:TXTLS(@"CancelButton")
						otherButton:nil
					 suppressionKey:nil
					suppressionText:nil];
}

/* Master controller internal handles for import. */
+ (void)importPreflight:(TLOPopupPromptReturnType)buttonPressed
{
	/* What button? */
	if (buttonPressed == TLOPopupPromptReturnPrimaryType) {
		NSOpenPanel *d = [NSOpenPanel openPanel];

		[d setCanChooseFiles:YES];
		[d setResolvesAliases:YES];
		[d setCanChooseDirectories:NO];
		[d setCanCreateDirectories:NO];
		[d setAllowsMultipleSelection:NO];

		[d beginWithCompletionHandler:^(NSInteger returnCode) {
			if (returnCode == NSOKButton) {
				NSURL *pathURL = [d.URLs safeObjectAtIndex:0];

				[self importPostflight:pathURL];
			}
		}];
	}
}

+ (void)importPostflight:(NSURL *)pathURL
{
	/* The loading screen is a generic way to show something during import. */
	[self.masterController.mainWindowLoadingScreen popLoadingConfigurationView];

	/* Disconnect and clear all. */
	IRCWorld *theWorld = self.worldController;

	for (IRCClient *u in theWorld.clients) {
		[u quit];
	}

	/* Begin import. */
}

#pragma mark -
#pragma mark Export

/* +exportPostflightForURL: handles the actual export. */
+ (void)exportPostflightForURL:(NSURL *)pathURL
{
	/* Save the world. Just like superman! */
	IRCWorld *theWorld = self.worldController;

	[theWorld save];

	/* Gather everything into one big dictionary. */
	NSDictionary *settings = [RZUserDefaults() dictionaryRepresentation];

	NSMutableDictionary *mutsettings = [settings mutableCopy];

	/* Cocoa filter. */
	/* Go through each top level object in our dictionary and remove any that
	 start with NS* and do not contain a space. These are considered part of
	 theh cocoa namespace and we do not want them between different installs. */
	for (NSString *key in settings) {
		if ([key hasPrefix:@"NS"] ||
			[key hasPrefix:@"Apple"] ||
			[key hasPrefix:@"WebKit"] ||
			[key hasPrefix:@"com.apple."])
		{
			[mutsettings removeObjectForKey:key];
		} else if ([key hasPrefix:@"Saved Window State —> Internal —> "]) {
			/* While we are going through the list, also remove window frames. */
			
			[mutsettings removeObjectForKey:key];
		}
	}

	/* Custom filter. */
	/* Some settings such as log folder scoped bookmark cannot be exported/imported so we will
	 drop that from our exported dictionary. Other things that cannot be handled is the main 
	 window frame. Also, any custom styles. */
	[mutsettings removeObjectForKey:@"LogTranscriptDestinationSecurityBookmark"];
	[mutsettings removeObjectForKey:@"Window -> Main Window"];

	NSString *themeName = [settings objectForKey:@"Theme -> Name"];

	if ([themeName hasPrefix:@"resource:"] == NO) { // It is custom.
 		[mutsettings removeObjectForKey:@"Theme -> Name"];
	}

	/* The export will be saved as binary. Two reasons: 1) Discourages user from
	 trying to tamper with stuff. 2) Smaller, faster. Mostly #1. */
	NSString *parseError;

	/* Create the new property list. */
	NSData *plist = [NSPropertyListSerialization dataFromPropertyList:mutsettings
															   format:NSPropertyListBinaryFormat_v1_0
													 errorDescription:&parseError];

	/* Do the actual write. */
	if (NSObjectIsEmpty(plist) || parseError) {
		LogToConsole(@"Error Creating Property List: %@", parseError);
	} else {
		BOOL writeResult = [plist writeToURL:pathURL atomically:YES];

		if (writeResult == NO) {
			LogToConsole(@"Write failed.");
		}
	}
}

/* Open sheet. */
+ (void)export
{
	/* Pop open panel. An open panel is used instead of save panel because we only
	 want the user selecting a folder, nothing else. */
	NSSavePanel *d = [NSSavePanel savePanel];

	[d setCanCreateDirectories:YES];
	[d setNameFieldStringValue:@"TextualPrefrences.plist"];

	[d setMessage:TXTLS(@"PreferencesExportSaveLocationDialogMessage")];

	[d beginWithCompletionHandler:^(NSInteger returnCode) {
		if (returnCode == NSOKButton) {
			[self exportPostflightForURL:d.URL];
		}
	}];
}

@end