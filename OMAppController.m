/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2011
	License:  Modified BSD  (see COPYING)
 */

#import "OMAppController.h"
#import "OMLayoutItemFactory.h"
#import "OMModelFactory.h"

// FIXME: Remove
@interface ETWidgetLayout (Private)
- (NSView *) layoutViewWithoutScrollView;
@end

@implementation OMAppController

@synthesize currentPresentationTitle, editingContext, mainUndoTrack;

- (void) dealloc
{
	DESTROY(editingContext);
	DESTROY(itemFactory);
	DESTROY(openedGroups);
	DESTROY(mainUndoTrack);
	DESTROY(currentPresentationTitle);
	[super dealloc];
}

- (id) initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
	self = [super initWithNibName: nil bundle: nil objectGraphContext: aContext];
	ASSIGN(itemFactory, [OMLayoutItemFactory factoryWithObjectGraphContext: aContext]);
	openedGroups = [[NSMutableSet alloc] init];
	return self;
}

- (void) setUpMenus
{
	[[ETApp mainMenu] addItem: [ETApp objectMenuItem]];
	[[ETApp mainMenu] addItem: [ETApp editMenuItem]];
	[[ETApp mainMenu] addItem: [ETApp viewMenuItem]];

	[[[[ETApp editMenuItem] submenu] itemWithTitle: _(@"Select All")]
		setAction: @selector(selectAllExceptInSourceList:)];

	[[[[ETApp viewMenuItem] submenu] itemWithTitle: _(@"List")] setState: NSOnState];
	ASSIGN(currentPresentationTitle,  _(@"List"));
}

- (void) setUpUndoTrack: (BOOL)clear
{
	ETAssert([self editingContext] != nil);
	ETUUID *trackUUID = [[NSUserDefaults standardUserDefaults] UUIDForKey: @"OMMainUndoTrackUUID"];

	if (trackUUID == nil)
	{
		trackUUID = [ETUUID UUID];
		[[NSUserDefaults standardUserDefaults] setUUID: trackUUID 
		                                        forKey: @"OMMainUndoTrackUUID"];
	}

	ASSIGN(mainUndoTrack, [COUndoTrack trackForName: [trackUUID stringValue]
	                             withEditingContext: [self editingContext]]);

	if (clear)
	{
		[mainUndoTrack clear];
	}
}

- (NSString *) storePath
{
	return [@"~/TestObjectStore" stringByExpandingTildeInPath];
}

- (void) setUpEditingContext: (BOOL)clear
{
	if (clear && [[NSFileManager defaultManager] fileExistsAtPath: [self storePath]])
	{
		NSError *error = nil;
		[[NSFileManager defaultManager] removeItemAtPath: [self storePath]
		                                           error: &error];
		ETAssert(error == nil);
	}
	COEditingContext *ctxt =
		[COEditingContext contextWithURL: [NSURL fileURLWithPath: [self storePath]]];
	ETAssert(ctxt != nil);

	ASSIGN(editingContext, ctxt);

	[[NSNotificationCenter defaultCenter]
		addObserver: self
	 	   selector: @selector(didCommit:)
	 	       name: COEditingContextDidChangeNotification
	 	     object: editingContext];
}

- (void) setUpAndShowBrowserUI
{
	[[itemFactory windowGroup] setController: self];
	[self browseMainGroup: nil];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notif
{
	BOOL clear = YES;

	[self setUpMenus];
	[self setUpEditingContext: clear];
	[self setUpUndoTrack: clear];
	[self setUpAndShowBrowserUI];
}

- (void) didCommit: (NSNotification *)notif
{
	COCommand *command = [[notif userInfo] objectForKey: kCOCommandKey];
	BOOL isUndoOrRedo = (command == nil);

	if (isUndoOrRedo)
		return;

	ETLog(@"Recording command %@ on %@", command, mainUndoTrack);

	ETAssert([mainUndoTrack currentNode] != nil);
}

- (void) prepareInitialFocusedItemInsideItem: (ETLayoutItemGroup *)browser
{
	// FIXME: Remove this workaround once we support some mechanism to declare a
	// initial focused item (similar to -[NSWindow initialFirstResponder])
	ETLayoutItem *contentViewItem = [browser itemForIdentifier: @"contentView"];
	id widgetView = [(ETWidgetLayout *)[contentViewItem layout] layoutViewWithoutScrollView];

	ETAssert(widgetView != nil);
	ETAssert([ETTool activeTool] != nil);
	[[ETTool activeTool] makeFirstKeyResponder: widgetView];
}

- (IBAction) browseMainGroup: (id)sender
{
	OMModelFactory *modelFactory =
		[[[OMModelFactory alloc] initWithEditingContext: [self editingContext]
	                                          undoTrack: mainUndoTrack] autorelease];
	ETLayoutItemGroup *browser = [itemFactory browserWithGroup: [modelFactory sourceListGroups]
	                                            editingContext: [self editingContext]];

	[[itemFactory windowGroup] addItem: browser];
	[openedGroups addObject: [modelFactory allObjectGroup]];

	// FIXME: Call -prepareInitialFocusedItemInsideItem: with some delay since
	// the view are not backed by windows yet (i.e. the layout update is run just
	// before the next event)
}

- (IBAction) undo: (id)sender
{
	[mainUndoTrack undo];
}

- (IBAction) redo: (id)sender
{
	[mainUndoTrack redo];
}

- (IBAction) browseUndoHistory: (id)sender
{
	ETAssert(mainUndoTrack != nil);
	ETLayoutItemGroup *browser = [[ETLayoutItemFactory factory] 
		historyBrowserWithRepresentedObject: mainUndoTrack title: nil];

	[[[ETLayoutItemFactory factory] windowGroup] addItem: browser];
}

@end
