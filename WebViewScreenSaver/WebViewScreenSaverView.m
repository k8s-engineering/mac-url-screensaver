//
//  WebViewScreenSaverView.m
//  WebViewScreenSaver
//
//  Created by Alastair Tse on 8/8/10.
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

#import "WebViewScreenSaverView.h"
#import "WKWebViewPrivate.h"
#import "WVSSAddress.h"
#import "WVSSLog.h"
#import "WVSSScreenIdentifier.h"

// ScreenSaverDefaults module name.
static NSString *const kScreenSaverName = @"WebViewScreenSaver";

NSNotificationName const WVSSConfigDismissed = @"webviewscreensaver.config.dismissed";
NSNotificationName const WVSSPreviewStopped = @"webviewscreensaver.preview.stopped";

@interface WebViewScreenSaverView () <WVSSConfigControllerDelegate,
                                      WKUIDelegate,
                                      WKNavigationDelegate>

// Timer callback that loads the next URL in the URL list.
- (void)loadNext:(NSTimer *)timer;

@end

@implementation WebViewScreenSaverView {
  WVSSConfig *_config;
  NSTimer *_timer;
  WKWebView *_webView;
  NSInteger _currentIndex;
  NSInteger _screenIndex;
  BOOL _screenIndexDetected;
}

@synthesize screenIndex = _screenIndex;

+ (BOOL)performGammaFade {
  return NO;
}

// Called by System Preferences/ScreenSaverEngine
- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  NSUserDefaults *prefs = [ScreenSaverDefaults defaultsForModuleWithName:kScreenSaverName];
  self = [self initWithFrame:frame isPreview:isPreview prefsStore:prefs];

  return self;
}

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview prefsStore:(NSUserDefaults *)prefs {
  self = [super initWithFrame:frame isPreview:isPreview];
  if (self) {
    WVSSLog(@"%@", self);
    [self setAutoresizesSubviews:YES];

    _currentIndex = 0;
    _screenIndex = 0;
    _screenIndexDetected = NO;

    // Simplified preview
    if (isPreview) {
      NSBundle *bundle = [NSBundle bundleForClass:self.class];
      NSImageView *logoView =
          [NSImageView imageViewWithImage:[bundle imageForResource:@"thumbnail"]];
      logoView.frame = self.bounds;
      logoView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
      [self addSubview:logoView];
    }

    // Load state from the preferences.
    _config = [[WVSSConfig alloc] initWithUserDefaults:prefs];
  }
  return self;
}

- (void)dealloc {
  WVSSTrace();
}

- (void)teardown {
  WVSSLog(@"%@", self);
  [NSDistributedNotificationCenter.defaultCenter removeObserver:self];

  [_webView removeFromSuperview];
  _webView = nil;

  [_timer invalidate];
  _timer = nil;
}

#pragma mark - Screen Detection

/// Detects which screen this view is running on. Called once at startAnimation
/// when the view has a window.
- (void)detectScreenIndex {
  if (_screenIndexDetected) return;

  _screenIndex = [WVSSScreenIdentifier screenIndexForView:self];
  _screenIndexDetected = YES;

  NSString *label = [WVSSScreenIdentifier labelForScreenIndex:_screenIndex];
  WVSSLog(@"Detected screen: %@ (index %ld)", label, (long)_screenIndex);
}

/// Returns the effective address list for this view's screen.
- (NSMutableArray *)effectiveAddresses {
  return [_config effectiveAddressesForScreenIndex:_screenIndex];
}

#pragma mark - Description

- (NSString *)frameToString:(NSRect)frame {
  return [NSString stringWithFormat:@"(x=%.f, y=%.f, w=%.f, h=%.f)", frame.origin.x, frame.origin.y,
                                    frame.size.width, frame.size.height];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"preview:%@ screen:%ld frame:%@ window:%p %@ scale:%.f",
                                    WVSSBoolStr(self.isPreview), (long)_screenIndex,
                                    [self frameToString:self.frame],
                                    self.window, [self frameToString:self.window.frame],
                                    self.window.backingScaleFactor];
}

#pragma mark - Configure Sheet

- (BOOL)hasConfigureSheet {
  return YES;
}

- (NSWindow *)configureSheet {
  WVSSLog(@"%@", self);
  self.configController = [[WVSSConfigController alloc] initWithConfig:_config];
  self.configController.delegate = self;
  return self.configController.sheet;
}

- (void)configController:(WVSSConfigController *)configController
      dismissConfigSheet:(NSWindow *)sheet {
  if (self.isPreview) {
    [self loadFromStart];
  }

  [[NSApplication sharedApplication] endSheet:sheet];
  self.configController = nil;

  [self postNotification:WVSSConfigDismissed];
}

#pragma mark - Notification Support

- (void)postNotification:(NSString *)notification {
  [NSDistributedNotificationCenter.defaultCenter
      postNotification:[[NSNotification alloc] initWithName:notification object:nil userInfo:nil]];
}

- (void)subscribeForNotifications {
  NSDistributedNotificationCenter *notifCenter = NSDistributedNotificationCenter.defaultCenter;

  [notifCenter addObserver:self
                  selector:@selector(screensaverDidStart:)
                      name:@"com.apple.screensaver.didstart"
                    object:nil];
  [notifCenter addObserver:self
                  selector:@selector(screensaverWillStop:)
                      name:@"com.apple.screensaver.willstop"
                    object:nil];
  [notifCenter addObserver:self
                  selector:@selector(screenIsLocked:)
                      name:@"com.apple.screenIsLocked"
                    object:nil];
  [notifCenter addObserver:self
                  selector:@selector(screenIsUnlocked:)
                      name:@"com.apple.screenIsUnlocked"
                    object:nil];
  [notifCenter addObserver:self
                  selector:@selector(screensaverDidStop:)
                      name:@"com.apple.screensaver.didstop"
                    object:nil];

  [notifCenter addObserver:self
                  selector:@selector(configDismissed:)
                      name:WVSSConfigDismissed
                    object:nil];
  [notifCenter addObserver:self
                  selector:@selector(previewStopped:)
                      name:WVSSPreviewStopped
                    object:nil];
}

// Tearing down other instances only happens under macOS 26 which uses multiple
- (void)configDismissed:(NSNotification *)notification {
  WVSSTrace();
  [self teardown];
}

- (void)previewStopped:(NSNotification *)notification {
  WVSSTrace();
  [self teardown];
}

#pragma mark ScreenSaverView

+ (WKWebView *)makeWebView:(NSRect)frame {
  WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
  WKPreferences *preferences = [[WKPreferences alloc] init];
  preferences.javaScriptCanOpenWindowsAutomatically = NO;
  configuration.preferences = preferences;

  WKWebView *webView = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
  webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  NSColor *color = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
  webView.layer.backgroundColor = color.CGColor;
  [webView setValue:@(YES)
             forKey:@"drawsTransparentBackground"];  // Deprecated and internal but works

  return webView;
}

- (void)startAnimation {
  [super startAnimation];
  WVSSLog(@"%@", self);

  if (self.isPreview || _webView) return;

  // Detect which screen this instance is on (must have window by now)
  [self detectScreenIndex];

  // Create the webview for the screensaver.
  _webView = [self.class makeWebView:self.bounds];
  _webView.UIDelegate = self;
  _webView.navigationDelegate = self;
  // Sonoma ScreenSaverEngine view hierarchy occludes webview pausing animations and JS.
  [_webView wvss_setWindowOcclusionDetectionEnabled:NO];
  [self addSubview:_webView];

  if (_currentIndex < [self numberOfAddresses]) {
    [self loadFromStart];
  }

  [self subscribeForNotifications];
}

- (void)stopAnimation {
  [super stopAnimation];
  WVSSTrace();

  if (self.isPreview) {
    [self postNotification:WVSSPreviewStopped];
  }

  [self teardown];
}

#pragma mark Loading URLs

- (void)loadFromStart {
  WVSSLog(@"animating: %@, screen: %ld", WVSSBoolStr(self.isAnimating), (long)_screenIndex);

  if (self.isAnimating) {
    _currentIndex = -1;
    [self loadNext:nil];
  }
}

- (void)loadNext:(NSTimer *)timer {
  NSMutableArray *addresses = [self effectiveAddresses];
  WVSSAddress *address = WVSSAddress.defaultAddress;
  NSInteger nextIndex = _currentIndex;

  // Last element, fetchURLs if they exist.
  if (_currentIndex == (NSInteger)addresses.count - 1) {
    [_config fetchIfNeeded];
  }

  // Progress the URL counter.
  if (addresses.count > 0) {
    nextIndex = (_currentIndex + 1) % (NSInteger)addresses.count;
    address = [addresses objectAtIndex:nextIndex];
  }
  WVSSLog(@"screen %ld loading [%ld/%lu]: %@", (long)_screenIndex, (long)nextIndex,
          (unsigned long)addresses.count, address.url);

  [self.class loadAddress:address target:_webView];
  [_timer invalidate];
  _timer = nil;

  if (address.duration < 0) return;  // Infinite
  _timer = [NSTimer scheduledTimerWithTimeInterval:address.duration
                                            target:self
                                          selector:@selector(loadNext:)
                                          userInfo:nil
                                           repeats:NO];
  _currentIndex = nextIndex;
}

/// Returns YES if the two URLs share the same base (scheme, host, port, path) 
/// regardless of fragment. Used to detect when we're navigating between hash-only
/// differences on the same page.
+ (BOOL)url:(NSURL *)url1 hasSameBaseAs:(NSURL *)url2 {
  if (!url1 || !url2) return NO;

  // Build URLs without fragments
  NSURLComponents *comp1 = [NSURLComponents componentsWithURL:url1 resolvingAgainstBaseURL:NO];
  NSURLComponents *comp2 = [NSURLComponents componentsWithURL:url2 resolvingAgainstBaseURL:NO];

  comp1.fragment = nil;
  comp2.fragment = nil;

  return [comp1.URL isEqual:comp2.URL];
}

+ (void)loadAddress:(WVSSAddress *)address target:(WKWebView *)webView {
  NSString *urlString = address.url;
  NSURL *url = [NSURL URLWithString:urlString];

  if (url.scheme == nil) {
    NSString *escapedUrlString = [urlString
        stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet
                                                               .URLPathAllowedCharacterSet];
    url = [NSURL URLWithString:[@"file://" stringByAppendingString:escapedUrlString]];
  }

  if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
    // Check if URLs share the same base (same host/path, differ only in fragment).
    // For single-page apps like Frigate, WKWebView won't reload when only the 
    // fragment changes. Force a full reload by adding a cache-busting parameter.
    NSURL *currentURL = webView.URL;
    NSURL *urlToLoad = url;
    
    if ([self url:url hasSameBaseAs:currentURL]) {
      // Add timestamp to force complete reload for same-base URLs
      NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
      NSString *existingQuery = components.query;
      NSString *cacheBuster = [NSString stringWithFormat:@"_wvss_t=%lld", (long long)[[NSDate date] timeIntervalSince1970]];
      if (existingQuery.length > 0) {
        components.query = [NSString stringWithFormat:@"%@&%@", existingQuery, cacheBuster];
      } else {
        components.query = cacheBuster;
      }
      urlToLoad = components.URL;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlToLoad];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [webView loadRequest:request];
  } else if ([url.scheme isEqualToString:@"file"] || url.scheme == nil) {
    [webView loadFileURL:url allowingReadAccessToURL:[url URLByDeletingLastPathComponent]];
  } else {
    // no-op
  }
}

- (NSUInteger)numberOfAddresses {
  return [self effectiveAddresses].count;
}

- (WVSSAddress *)addressForIndex:(NSInteger)index {
  return [[self effectiveAddresses] objectAtIndex:index];
}

- (void)animateOneFrame {
  [super animateOneFrame];
}

#pragma mark Focus Overrides

// A bunch of methods that captures all the input events to prevent
// the webview from getting any keyboard focus.

- (NSView *)hitTest:(NSPoint)aPoint {
  return self;
}

- (BOOL)acceptsFirstResponder {
  return NO;
}

- (BOOL)resignFirstResponder {
  return NO;
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  // Don't open new windows.
  if (navigationAction.targetFrame == nil) {
    decisionHandler(WKNavigationActionPolicyCancel);
  }
  decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - System Screensaver Notifications

- (void)screensaverDidStart:(NSNotification *)notification {
  WVSSTrace();
}

- (void)screensaverDidStop:(NSNotification *)notification {
  WVSSTrace();
}

- (void)screenIsLocked:(NSNotification *)notification {
  WVSSTrace();
}

- (void)screenIsUnlocked:(NSNotification *)notification {
  WVSSTrace();
}

// Inspired by: https://github.com/JohnCoates/Aerial/commit/8c78e7cc4f77f4417371966ae7666125d87496d1
- (void)screensaverWillStop:(NSNotification *)notification {
  WVSSTrace();
  if (@available(macOS 14.0, *)) {
    [self teardown];
  }
}

@end
