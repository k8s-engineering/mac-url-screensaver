//
//  WVSSScreenIdentifier.m
//  WebViewScreenSaver
//
//  Multi-screen support utility.
//
//  Copyright 2026 Don O'Neill. Licensed under Apache 2.0.
//

#import "WVSSScreenIdentifier.h"
#import "WVSSLog.h"

NSInteger const kWVSSMaxScreens = 6;

@implementation WVSSScreenIdentifier

+ (NSInteger)screenIndexForView:(NSView *)view {
  NSWindow *window = view.window;
  if (!window) {
    WVSSLog(@"screenIndexForView: no window, returning 0");
    return 0;
  }

  NSScreen *viewScreen = window.screen;
  if (!viewScreen) {
    WVSSLog(@"screenIndexForView: no screen on window, returning 0");
    return 0;
  }

  // Match by display ID for reliability
  CGDirectDisplayID viewDisplayID = [self displayIDForScreen:viewScreen];
  NSArray<NSScreen *> *screens = [NSScreen screens];

  for (NSInteger i = 0; i < screens.count; i++) {
    CGDirectDisplayID screenDisplayID = [self displayIDForScreen:screens[i]];
    if (screenDisplayID == viewDisplayID) {
      WVSSLog(@"screenIndexForView: matched screen %ld (displayID: %u)", (long)i, viewDisplayID);
      return i;
    }
  }

  // Fallback: match by frame origin proximity
  NSPoint viewOrigin = window.frame.origin;
  CGFloat minDistance = CGFLOAT_MAX;
  NSInteger bestIndex = 0;

  for (NSInteger i = 0; i < screens.count; i++) {
    NSRect screenFrame = screens[i].frame;
    CGFloat dx = viewOrigin.x - screenFrame.origin.x;
    CGFloat dy = viewOrigin.y - screenFrame.origin.y;
    CGFloat distance = sqrt(dx * dx + dy * dy);
    if (distance < minDistance) {
      minDistance = distance;
      bestIndex = i;
    }
  }

  WVSSLog(@"screenIndexForView: fallback matched screen %ld (distance: %.0f)", (long)bestIndex,
          minDistance);
  return bestIndex;
}

+ (CGDirectDisplayID)displayIDForScreen:(NSScreen *)screen {
  NSDictionary *deviceDescription = screen.deviceDescription;
  NSNumber *screenNumber = deviceDescription[@"NSScreenNumber"];
  return (CGDirectDisplayID)screenNumber.unsignedIntValue;
}

+ (CGDirectDisplayID)displayIDForScreenIndex:(NSInteger)index {
  NSArray<NSScreen *> *screens = [NSScreen screens];
  if (index < 0 || index >= (NSInteger)screens.count) {
    return CGMainDisplayID();
  }
  return [self displayIDForScreen:screens[index]];
}

+ (NSInteger)numberOfScreens {
  return (NSInteger)[NSScreen screens].count;
}

+ (NSString *)labelForScreenIndex:(NSInteger)index {
  NSArray<NSScreen *> *screens = [NSScreen screens];
  if (index < 0 || index >= (NSInteger)screens.count) {
    return [NSString stringWithFormat:@"Screen %ld", (long)(index + 1)];
  }

  NSScreen *screen = screens[index];
  NSString *name = nil;

  // macOS 10.15+ has localizedName
  if (@available(macOS 10.15, *)) {
    name = screen.localizedName;
  }

  if (name.length) {
    return [NSString stringWithFormat:@"Screen %ld (%@)", (long)(index + 1), name];
  }

  // Fallback: label by position
  if (index == 0) {
    return @"Screen 1 (Primary)";
  }
  return [NSString stringWithFormat:@"Screen %ld", (long)(index + 1)];
}

+ (NSString *)keySuffixForScreenIndex:(NSInteger)index {
  return [NSString stringWithFormat:@"_screen_%ld", (long)index];
}

@end
