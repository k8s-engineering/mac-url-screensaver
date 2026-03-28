//
//  WVSSScreenIdentifier.h
//  WebViewScreenSaver
//
//  Multi-screen support utility.
//  Detects which physical display a ScreenSaverView is running on
//  and maps it to a stable screen index for per-screen configuration.
//
//  Copyright 2026 Don O'Neill. Licensed under Apache 2.0.
//

#import <AppKit/AppKit.h>
#import <ScreenSaver/ScreenSaver.h>

NS_ASSUME_NONNULL_BEGIN

/// Maximum number of screens we support per-screen configs for.
extern NSInteger const kWVSSMaxScreens;

@interface WVSSScreenIdentifier : NSObject

/// Returns the screen index (0-based) for a given ScreenSaverView.
/// Matches the view's window screen against [NSScreen screens].
/// Returns 0 if no match is found (fallback to primary).
+ (NSInteger)screenIndexForView:(NSView *)view;

/// Returns the display ID (CGDirectDisplayID) for a given screen index.
+ (CGDirectDisplayID)displayIDForScreenIndex:(NSInteger)index;

/// Returns the number of currently connected screens.
+ (NSInteger)numberOfScreens;

/// Returns a human-readable label for a screen index, e.g. "Screen 1 (Built-in)" or "Screen 2 (LG UltraFine)".
+ (NSString *)labelForScreenIndex:(NSInteger)index;

/// Returns a persistent key suffix for a screen index, suitable for NSUserDefaults keys.
+ (NSString *)keySuffixForScreenIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
