//
//  WVSSConfigController.m
//  WebViewScreenSaver
//
//  Created by Alastair Tse on 26/04/2015.
//  Multi-screen support added 2026.
//
//  Copyright 2015 Alastair Tse.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "WVSSConfigController.h"
#import "WVSSAddress.h"
#import "WVSSConfig.h"
#import "WVSSLog.h"
#import "WVSSScreenIdentifier.h"
#import "WebViewScreenSaverView.h"

#import <WebKit/WebKit.h>

static NSString *const kURLTableRow = @"kURLTableRow";
// Configuration sheet columns.
static NSString *const kTableColumnURL = @"url";
static NSString *const kTableColumnTime = @"time";
static NSString *const kTableColumnPreview = @"preview";

@interface WVSSConfigController ()
@property(nonatomic, strong) WVSSConfig *config;
/// Per-screen mode checkbox (added programmatically).
@property(nonatomic, strong) NSButton *perScreenCheckbox;
/// Screen selector popup button (added programmatically).
@property(nonatomic, strong) NSPopUpButton *screenPopup;
/// Status label showing detected number of screens.
@property(nonatomic, strong) NSTextField *screenStatusLabel;
/// Text field for entering a URL before clicking "Add URL".
@property(nonatomic, strong) NSTextField *addURLInputField;
/// Currently selected screen index (-1 = global/all screens).
@property(nonatomic, assign) NSInteger selectedScreenIndex;
@end

@implementation WVSSConfigController

- (instancetype)initWithConfig:(WVSSConfig *)config {
  self = [super init];
  if (self) {
    WVSSTrace();
    self.config = config;
    self.selectedScreenIndex = -1;  // Default to "All Screens"
    [self configureSheet];
  }
  return self;
}

- (void)dealloc {
  WVSSTrace();
}

#pragma mark - Active Addresses

/// Returns the address list currently being edited (depends on screen selection).
- (NSMutableArray *)activeAddresses {
  if (self.selectedScreenIndex < 0 || !self.config.perScreenMode) {
    return self.config.addresses;
  }
  return [self.config addressesForScreenIndex:self.selectedScreenIndex];
}

- (void)synchronize {
  self.config.addressListURL = self.urlsURLField.stringValue;
  [self.config synchronize];
}

- (void)appendAddress {
  // Force the window to commit any in-progress text editing so we read
  // the current value of the input field, not an empty uncommitted string.
  [self.sheet endEditingFor:nil];

  // Read URL from the input field; fall back to a placeholder.
  NSString *urlText = [self.addURLInputField.stringValue
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!urlText.length) {
    urlText = @"https://";
  }

  WVSSAddress *address = [WVSSAddress addressWithURL:urlText
                                            duration:[WVSSAddress defaultDuration]];
  NSMutableArray *active = [self activeAddresses];
  [active addObject:address];

  // When in per-screen mode editing "All Screens", also add to each screen list.
  if (self.config.perScreenMode && self.selectedScreenIndex < 0) {
    NSInteger screenCount = [WVSSScreenIdentifier numberOfScreens];
    for (NSInteger i = 0; i < screenCount; i++) {
      WVSSAddress *copy = [WVSSAddress addressWithURL:urlText
                                             duration:[WVSSAddress defaultDuration]];
      [[self.config addressesForScreenIndex:i] addObject:copy];
    }
  }

  [self.urlTable reloadData];

  // Clear input field and select new row.
  self.addURLInputField.stringValue = @"";
  NSInteger newRow = (NSInteger)active.count - 1;
  [self.urlTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
  [self.urlTable scrollRowToVisible:newRow];

  WVSSLog(@"Added URL at row %ld: %@", (long)newRow, urlText);
}

- (void)removeAddressAtIndex:(NSInteger)index {
  NSMutableArray *active = [self activeAddresses];
  if (index < 0 || index >= (NSInteger)active.count) return;

  WVSSAddress *removed = [active objectAtIndex:index];
  [active removeObjectAtIndex:(NSUInteger)index];

  // When in per-screen mode editing "All Screens", also remove matching URL
  // from each per-screen list so stale entries don't persist.
  if (self.config.perScreenMode && self.selectedScreenIndex < 0) {
    NSInteger screenCount = [WVSSScreenIdentifier numberOfScreens];
    for (NSInteger i = 0; i < screenCount; i++) {
      NSMutableArray *screenAddrs = [self.config addressesForScreenIndex:i];
      // Find and remove first entry with matching URL.
      for (NSInteger j = 0; j < (NSInteger)screenAddrs.count; j++) {
        WVSSAddress *addr = screenAddrs[j];
        if ([addr.url isEqualToString:removed.url]) {
          [screenAddrs removeObjectAtIndex:j];
          WVSSLog(@"Also removed '%@' from screen %ld", removed.url, (long)i);
          break;
        }
      }
    }
  }

  [self.urlTable reloadData];
}

#pragma mark - Actions

- (IBAction)addRow:(id)sender {
  [self appendAddress];
}

- (IBAction)removeRow:(id)sender {
  NSInteger row = [self.urlTable selectedRow];
  if (row != -1) {
    [self removeAddressAtIndex:row];
  }
}

- (IBAction)resetData:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:@"Clear History"];
  [alert setInformativeText:@"Clears history, cookies, cache and more."];
  [alert setIcon:[NSImage imageNamed:NSImageNameCaution]];
  [alert addButtonWithTitle:@"Clear Data"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert beginSheetModalForWindow:self.sheet
                completionHandler:^(NSModalResponse returnCode) {
                  if (returnCode == NSAlertFirstButtonReturn) {
                    [self clearWebViewHistory];
                  }
                }];
}

- (void)clearWebViewHistory {
  NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
  NSDate *since = [NSDate dateWithTimeIntervalSince1970:0];
  [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                             modifiedSince:since
                                         completionHandler:^{
                                           WVSSLog(@"Web cache cleared");
                                         }];
}

- (IBAction)openLogsFolder:(id)sender {
  [NSWorkspace.sharedWorkspace openFile:WVSSFileLogger.defaultLogger.logDirectory];
}

#pragma mark - Multi-screen Actions

- (void)perScreenToggled:(id)sender {
  // Commit in-progress table edits before changing mode.
  [self.sheet endEditingFor:nil];

  BOOL newValue = (self.perScreenCheckbox.state == NSControlStateValueOn);
  self.config.perScreenMode = newValue;

  // When turning on per-screen mode, always synchronize per-screen data
  // from currently visible global list so they stay consistent.
  if (newValue) {
    [self.config distributeGlobalAddressesToAllScreens];
  }

  [self updateScreenUIState];
  [self.urlTable reloadData];
}

- (void)screenPopupChanged:(id)sender {
  // Commit in-progress table edits before switching screen context.
  [self.sheet endEditingFor:nil];

  NSInteger index = self.screenPopup.indexOfSelectedItem;
  if (index == 0) {
    self.selectedScreenIndex = -1;  // "All Screens"
  } else {
    self.selectedScreenIndex = index - 1;  // Screen 0, 1, 2...
  }
  WVSSLog(@"Screen selection changed to: %ld", (long)self.selectedScreenIndex);
  [self.urlTable reloadData];
}

- (void)updateScreenUIState {
  BOOL perScreen = self.config.perScreenMode;
  self.screenPopup.enabled = perScreen;
  
  if (!perScreen) {
    [self.screenPopup selectItemAtIndex:0];  // "All Screens"
    self.selectedScreenIndex = -1;
  }
}

#pragma mark Bundle

- (NSArray *)bundleHTML {
  NSString *resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSError *error = nil;
  NSArray *bundleResourceContents =
      [[NSFileManager defaultManager] contentsOfDirectoryAtPath:resourcePath error:&error];

  NSMutableArray *bundleURLs = [NSMutableArray array];
  for (NSString *filename in bundleResourceContents) {
    if ([[filename pathExtension] isEqual:@"html"]) {
      NSString *path = [resourcePath stringByAppendingPathComponent:filename];
      NSURL *urlForPath = [NSURL fileURLWithPath:path];
      WVSSAddress *address = [WVSSAddress addressWithURL:[urlForPath absoluteString] duration:180];
      [bundleURLs addObject:address];
    }
  }
  return [bundleURLs count] ? bundleURLs : nil;
}

#pragma mark - User Interface

- (NSWindow *)configureSheet {
  if (!self.sheet) {
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    if (![thisBundle loadNibNamed:@"ConfigureSheet" owner:self topLevelObjects:NULL]) {
      // NSLog(@"Unable to load configuration sheet");
    }

    // If there is a urlListURL.
    if (self.config.addressListURL.length) {
      self.urlsURLField.stringValue = self.config.addressListURL;
    } else {
      self.urlsURLField.stringValue = @"";
    }

    // URLs
    [self.urlTable setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [self.urlTable registerForDraggedTypes:[NSArray arrayWithObject:kURLTableRow]];
    [self.urlTable setTarget:self];
    [self.urlTable setAction:@selector(urlTableClicked:)];
    [self.urlTable setDoubleAction:@selector(urlTableDoubleClicked:)];

    [self.fetchURLCheckbox setIntegerValue:self.config.shouldFetchAddressList];
    [self.urlsURLField setEnabled:self.config.shouldFetchAddressList];

    // --- Multi-screen UI (added programmatically above the URL table) ---
    [self addMultiScreenUI];
  }
  return self.sheet;
}

/// Adds per-screen UI controls above the existing URL table.
- (void)addMultiScreenUI {
  NSView *contentView = self.sheetContents ?: self.sheet.contentView;

  // Find the URL table's scroll view to position our controls.
  NSScrollView *scrollView = self.urlTable.enclosingScrollView;
  NSView *boxContentView = scrollView.superview;

  // Find and hide the static "Addresses" label from the XIB so we can replace
  // it with the per-screen checkbox + popup row.
  if (boxContentView) {
    for (NSView *sub in boxContentView.subviews) {
      if ([sub isKindOfClass:[NSTextField class]] && ![sub isKindOfClass:[NSButton class]]) {
        NSTextField *tf = (NSTextField *)sub;
        if ([tf.stringValue isEqualToString:@"Addresses"]) {
          tf.hidden = YES;
          break;
        }
      }
    }
  }

  // --- Per-Screen Mode Checkbox ---
  self.perScreenCheckbox = [NSButton checkboxWithTitle:@"Per-screen URLs"
                                                target:self
                                                action:@selector(perScreenToggled:)];
  self.perScreenCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
  self.perScreenCheckbox.state =
      self.config.perScreenMode ? NSControlStateValueOn : NSControlStateValueOff;
  self.perScreenCheckbox.toolTip = @"Configure different URLs for each screen";
  self.perScreenCheckbox.font = [NSFont boldSystemFontOfSize:12];
  [boxContentView addSubview:self.perScreenCheckbox];

  // --- Screen Selector Popup ---
  self.screenPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
  self.screenPopup.translatesAutoresizingMaskIntoConstraints = NO;
  self.screenPopup.font = [NSFont systemFontOfSize:11];

  // Populate with "All Screens" + each detected screen
  [self.screenPopup addItemWithTitle:@"All Screens"];
  NSInteger screenCount = [WVSSScreenIdentifier numberOfScreens];
  for (NSInteger i = 0; i < screenCount; i++) {
    NSString *label = [WVSSScreenIdentifier labelForScreenIndex:i];
    [self.screenPopup addItemWithTitle:label];
  }
  [self.screenPopup setTarget:self];
  [self.screenPopup setAction:@selector(screenPopupChanged:)];
  [boxContentView addSubview:self.screenPopup];

  // --- Status Label (compact, right-aligned) ---
  self.screenStatusLabel = [NSTextField labelWithString:
      [NSString stringWithFormat:@"%ld screens", (long)screenCount]];
  self.screenStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.screenStatusLabel.font = [NSFont systemFontOfSize:10];
  self.screenStatusLabel.textColor = NSColor.tertiaryLabelColor;
  self.screenStatusLabel.alignment = NSTextAlignmentRight;
  [self.screenStatusLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                                          forOrientation:NSLayoutConstraintOrientationHorizontal];
  [boxContentView addSubview:self.screenStatusLabel];

  // --- URL Input Field (next to Add/Remove buttons) ---
  self.addURLInputField = [[NSTextField alloc] initWithFrame:NSZeroRect];
  self.addURLInputField.translatesAutoresizingMaskIntoConstraints = NO;
  self.addURLInputField.placeholderString = @"https://example.com";
  self.addURLInputField.font = [NSFont systemFontOfSize:12];
  self.addURLInputField.bezelStyle = NSTextFieldRoundedBezel;
  self.addURLInputField.editable = YES;
  self.addURLInputField.selectable = YES;
  self.addURLInputField.toolTip = @"Type a URL here, then click Add URL";
  [boxContentView addSubview:self.addURLInputField];

  // Find the "Add URL" and "Remove URL" buttons in the box content view.
  NSButton *addButton = nil;
  NSButton *removeButton = nil;
  for (NSView *subview in boxContentView.subviews) {
    if ([subview isKindOfClass:[NSButton class]]) {
      NSButton *btn = (NSButton *)subview;
      if ([btn.title isEqualToString:@"Add URL"]) addButton = btn;
      if ([btn.title isEqualToString:@"Remove URL"]) removeButton = btn;
    }
  }

  // --- Layout Constraints ---
  // Per-screen row: 6px above the scroll view, all within boxContentView.
  [NSLayoutConstraint activateConstraints:@[
    // Checkbox: left-aligned, above scroll view
    [self.perScreenCheckbox.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
    [self.perScreenCheckbox.bottomAnchor constraintEqualToAnchor:scrollView.topAnchor
                                                        constant:-6],

    // Popup: right of checkbox, vertically centered with it
    [self.screenPopup.leadingAnchor
        constraintEqualToAnchor:self.perScreenCheckbox.trailingAnchor
                       constant:8],
    [self.screenPopup.centerYAnchor
        constraintEqualToAnchor:self.perScreenCheckbox.centerYAnchor],

    // Status label: right of popup, right-aligned to scroll view edge
    [self.screenStatusLabel.leadingAnchor constraintEqualToAnchor:self.screenPopup.trailingAnchor
                                                         constant:6],
    [self.screenStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:scrollView.trailingAnchor],
    [self.screenStatusLabel.centerYAnchor
        constraintEqualToAnchor:self.perScreenCheckbox.centerYAnchor],
  ]];

  // URL input field: next to buttons
  if (addButton && removeButton) {
    [NSLayoutConstraint activateConstraints:@[
      [self.addURLInputField.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
      [self.addURLInputField.centerYAnchor constraintEqualToAnchor:removeButton.centerYAnchor],
      [self.addURLInputField.trailingAnchor constraintEqualToAnchor:removeButton.leadingAnchor
                                                           constant:-8],
      [self.addURLInputField.heightAnchor constraintEqualToConstant:22],
    ]];
  }

  [self updateScreenUIState];
}

- (IBAction)dismissConfigSheet:(id)sender {
  // Ensure active text edits are committed before synchronize.
  [self.sheet endEditingFor:nil];
  [self synchronize];
  [self.delegate configController:self dismissConfigSheet:self.sheet];
}

#pragma mark NSTableView

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  // In IB the tableColumn has the identifier set to the same string as the keys in our dictionary
  NSString *identifier = [tableColumn identifier];

  NSMutableArray *addresses = [self activeAddresses];
  if (row < 0 || row >= (NSInteger)addresses.count) return nil;
  WVSSAddress *address = [addresses objectAtIndex:row];

  if ([identifier isEqual:kTableColumnURL]) {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    cellView.textField.stringValue = address.url;
    return cellView;
  } else if ([identifier isEqual:kTableColumnTime]) {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    cellView.textField.stringValue = [[NSNumber numberWithLong:address.duration] stringValue];
    return cellView;
  } else if ([identifier isEqual:kTableColumnPreview]) {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    return cellView;
  } else {
    NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
  }
  return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return (NSInteger)[self activeAddresses].count;
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint {
  return YES;
}

- (BOOL)tableView:(NSTableView *)tv
    writeRowsWithIndexes:(NSIndexSet *)rowIndexes
            toPasteboard:(NSPasteboard *)pboard {
  // Copy the row numbers to the pasteboard.
  NSData *serializedIndexes = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
  [pboard declareTypes:[NSArray arrayWithObject:kURLTableRow] owner:self];
  [pboard setData:serializedIndexes forType:kURLTableRow];
  return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv
                validateDrop:(id)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op {
  // Add code here to validate the drop
  return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation {
  NSPasteboard *pboard = [info draggingPasteboard];
  NSData *rowData = [pboard dataForType:kURLTableRow];
  NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
  NSInteger dragRow = [rowIndexes firstIndex];

  NSMutableArray *addresses = [self activeAddresses];
  id draggedObject = [addresses objectAtIndex:dragRow];

  if (dragRow < row) {
    [addresses insertObject:draggedObject atIndex:row];
    [addresses removeObjectAtIndex:dragRow];
    [self.urlTable reloadData];
  } else {
    [addresses removeObjectAtIndex:dragRow];
    [addresses insertObject:draggedObject atIndex:row];
    [self.urlTable reloadData];
  }
  return YES;
}

#pragma mark -

- (IBAction)tableViewCellDidEdit:(NSTextField *)textField {
  NSInteger col = [self.urlTable columnForView:textField];
  NSInteger row = [self.urlTable rowForView:textField];

  if (col < 0 || row < 0) return;

  NSTableColumn *column = [self.urlTable.tableColumns objectAtIndex:col];
  NSString *identifier = column.identifier;

  NSMutableArray *addresses = [self activeAddresses];
  if (row >= (NSInteger)addresses.count) return;

  if ([identifier isEqual:kTableColumnURL]) {
    WVSSAddress *address = [addresses objectAtIndex:row];
    address.url = textField.stringValue;
    WVSSLog(@"URL edited at row %ld: %@", (long)row, textField.stringValue);
  } else if ([identifier isEqual:kTableColumnTime]) {
    WVSSAddress *address = [addresses objectAtIndex:row];
    address.duration = [textField.stringValue intValue];
    WVSSLog(@"Duration edited at row %ld: %d", (long)row, [textField.stringValue intValue]);
  }
}

/// Start editing URL/Seconds for the currently clicked cell.
- (void)beginEditingClickedCellWithEvent:(NSEvent *)event {
  NSInteger row = self.urlTable.clickedRow;
  NSInteger col = self.urlTable.clickedColumn;
  if (row < 0 || col < 0) return;

  NSTableColumn *column = self.urlTable.tableColumns[col];
  NSString *identifier = column.identifier;
  if (!([identifier isEqual:kTableColumnURL] || [identifier isEqual:kTableColumnTime])) {
    return;
  }

  [self.urlTable editColumn:col row:row withEvent:event select:YES];
}

/// Start editing URL/Seconds on single-click so changes don't feel delayed.
- (void)urlTableClicked:(id)sender {
  [self beginEditingClickedCellWithEvent:NSApp.currentEvent];
}

/// Keep double-click behavior too (same editing path).
- (void)urlTableDoubleClicked:(id)sender {
  [self beginEditingClickedCellWithEvent:NSApp.currentEvent];
}

- (IBAction)toggleFetchingURLs:(id)sender {
  BOOL currentValue = self.config.shouldFetchAddressList;
  self.config.shouldFetchAddressList = !currentValue;
  [self.fetchURLCheckbox setIntegerValue:self.config.shouldFetchAddressList];
  [self.urlsURLField setEnabled:self.config.shouldFetchAddressList];
}

- (IBAction)previewButtonClicked:(NSButton *)sender {
  NSInteger row = [self.urlTable rowForView:sender.superview];

  NSMutableArray *addresses = [self activeAddresses];
  if (row < 0 || row >= (NSInteger)addresses.count) return;
  WVSSAddress *address = [addresses objectAtIndex:row];
  [self openAddress:address];
}

- (void)openAddress:(WVSSAddress *)address {
  NSPoint mouse = NSEvent.mouseLocation;
  NSRect bounds = NSMakeRect(0, 0, 1024, 768);
  NSRect frame =
      NSOffsetRect(bounds, mouse.x - bounds.size.width / 2, mouse.y - bounds.size.height / 2);
  NSWindow *window =
      [[NSWindow alloc] initWithContentRect:NSIntegralRect(frame)
                                  styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskTitled |
                                            NSWindowStyleMaskResizable
                                    backing:NSBackingStoreBuffered
                                      defer:YES];

  WKWebView *webView = [WebViewScreenSaverView makeWebView:bounds];
  [window.contentView addSubview:webView];

  [[[NSWindowController alloc] initWithWindow:window] showWindow:window];
  [WebViewScreenSaverView loadAddress:address target:webView];
}

@end
