//
//  WVSSConfig.h
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

#import <Foundation/Foundation.h>

@class WVSSAddress;

@interface WVSSConfig : NSObject

/// Global address list (used when perScreenMode is OFF, or as fallback).
@property(nonatomic, strong, readonly) NSMutableArray *addresses;

/// URL for fetching address list remotely.
@property(nonatomic, strong) NSString *addressListURL;

/// Whether to fetch addresses from a remote URL.
@property(nonatomic, assign) BOOL shouldFetchAddressList;

/// When YES, each screen gets its own URL list. When NO, all screens share `addresses`.
@property(nonatomic, assign) BOOL perScreenMode;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;
- (void)synchronize;
- (void)fetchIfNeeded;

#pragma mark - Multi-screen support

/// Returns the address list for a specific screen index.
/// In perScreenMode, returns the screen-specific list (may be empty).
/// Otherwise, returns the global `addresses` list.
- (NSMutableArray *)addressesForScreenIndex:(NSInteger)screenIndex;

/// Sets the address list for a specific screen.
- (void)setAddresses:(NSMutableArray *)addresses forScreenIndex:(NSInteger)screenIndex;

/// Returns the effective address list for a screen — per-screen if configured, global as fallback.
- (NSMutableArray *)effectiveAddressesForScreenIndex:(NSInteger)screenIndex;

/// Copies global addresses into per-screen slots that are currently empty.
/// Existing per-screen lists are preserved.
- (void)distributeGlobalAddressesToAllScreens;

@end
