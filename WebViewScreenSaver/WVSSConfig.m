//
//  WVSSConfig.m
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

#import "WVSSConfig.h"
#import "WVSSAddress.h"
#import "WVSSAddressListFetcher.h"
#import "WVSSLog.h"
#import "WVSSScreenIdentifier.h"

// ScreenSaverDefault Keys
static NSString *const kScreenSaverFetchURLsKey = @"kScreenSaverFetchURLs";  // BOOL
static NSString *const kScreenSaverURLsURLKey = @"kScreenSaverURLsURL";      // NSString (URL)
static NSString *const kScreenSaverURLListKey = @"kScreenSaverURLList";  // NSArray of NSDictionary
static NSString *const kScreenSaverPerScreenModeKey = @"kScreenSaverPerScreenMode";  // BOOL

@interface WVSSConfig () <WVSSAddressListFetcherDelegate>
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) NSMutableArray *addresses;
/// Per-screen address storage: key = @(screenIndex), value = NSMutableArray of WVSSAddress.
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray *> *screenAddresses;
@end

@implementation WVSSConfig {
  WVSSAddressListFetcher *_fetcher;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
  self = [super init];
  if (self) {
    self.userDefaults = userDefaults;

    // Load global addresses (backward compatible)
    self.addresses = [self loadAddressesFromUserDefaults:userDefaults forKey:kScreenSaverURLListKey];
    self.addressListURL = [userDefaults stringForKey:kScreenSaverURLsURLKey];
    self.shouldFetchAddressList = [userDefaults boolForKey:kScreenSaverFetchURLsKey];
    self.perScreenMode = [userDefaults boolForKey:kScreenSaverPerScreenModeKey];

    if (!self.addresses) {
      self.addresses = [NSMutableArray array];
    }

    // Load per-screen addresses
    self.screenAddresses = [NSMutableDictionary dictionary];
    for (NSInteger i = 0; i < kWVSSMaxScreens; i++) {
      NSString *key = [self urlListKeyForScreenIndex:i];
      NSMutableArray *screenAddrs = [self loadAddressesFromUserDefaults:userDefaults forKey:key];
      if (screenAddrs.count > 0) {
        self.screenAddresses[@(i)] = screenAddrs;
      }
    }

    WVSSLog(@"Loaded config: perScreenMode=%@, global=%lu addresses, screens=%lu",
            WVSSBoolStr(self.perScreenMode), (unsigned long)self.addresses.count,
            (unsigned long)self.screenAddresses.count);

    [self appendSampleAddressIfEmpty];
    [self fetchIfNeeded];
  }
  return self;
}

- (void)appendSampleAddressIfEmpty {
  if (self.shouldFetchAddressList) return;

  if (!self.addresses.count) {
    [self.addresses addObject:[WVSSAddress defaultAddress]];
  }
}

- (NSString *)urlListKeyForScreenIndex:(NSInteger)index {
  NSString *suffix = [WVSSScreenIdentifier keySuffixForScreenIndex:index];
  return [kScreenSaverURLListKey stringByAppendingString:suffix];
}

#pragma mark - Address Loading

- (NSMutableArray *)loadAddressesFromUserDefaults:(NSUserDefaults *)userDefaults
                                           forKey:(NSString *)key {
  NSArray *addressesFromUserDefaults = [[userDefaults arrayForKey:key] mutableCopy];
  NSMutableArray *addresses = [NSMutableArray array];
  for (NSDictionary *addressDictionary in addressesFromUserDefaults) {
    NSString *url = addressDictionary[kWVSSAddressURLKey];
    NSInteger time = [addressDictionary[kWVSSAddressTimeKey] integerValue];
    if (url) {
      WVSSAddress *address = [WVSSAddress addressWithURL:url duration:time];
      [addresses addObject:address];
    }
  }
  return addresses;
}

- (void)saveAddresses:(NSArray *)addresses
      toUserDefaults:(NSUserDefaults *)userDefaults
              forKey:(NSString *)key {
  NSMutableArray *addressesForUserDefaults = [NSMutableArray array];
  for (WVSSAddress *address in addresses) {
    [addressesForUserDefaults addObject:[address dictionaryRepresentation]];
  }
  [userDefaults setObject:addressesForUserDefaults forKey:key];
}

#pragma mark - Synchronize

- (void)synchronize {
  // Save global addresses
  [self saveAddresses:self.addresses toUserDefaults:self.userDefaults forKey:kScreenSaverURLListKey];

  // Save per-screen addresses
  for (NSInteger i = 0; i < kWVSSMaxScreens; i++) {
    NSString *key = [self urlListKeyForScreenIndex:i];
    NSMutableArray *screenAddrs = self.screenAddresses[@(i)];
    if (screenAddrs.count > 0) {
      [self saveAddresses:screenAddrs toUserDefaults:self.userDefaults forKey:key];
    } else {
      [self.userDefaults removeObjectForKey:key];
    }
  }

  // Save flags
  [self.userDefaults setBool:self.shouldFetchAddressList forKey:kScreenSaverFetchURLsKey];
  [self.userDefaults setBool:self.perScreenMode forKey:kScreenSaverPerScreenModeKey];

  if (self.addressListURL.length) {
    [self.userDefaults setObject:self.addressListURL forKey:kScreenSaverURLsURLKey];
  } else {
    [self.userDefaults removeObjectForKey:kScreenSaverURLsURLKey];
  }
  [self.userDefaults synchronize];

  WVSSLog(@"Config synchronized: perScreenMode=%@", WVSSBoolStr(self.perScreenMode));
}

- (void)addAddressWithURL:(NSString *)url duration:(NSInteger)duration {
  WVSSAddress *address = [WVSSAddress addressWithURL:url duration:duration];
  [self.addresses addObject:address];
}

#pragma mark - Multi-screen support

- (NSMutableArray *)addressesForScreenIndex:(NSInteger)screenIndex {
  NSMutableArray *screenAddrs = self.screenAddresses[@(screenIndex)];
  if (!screenAddrs) {
    screenAddrs = [NSMutableArray array];
    self.screenAddresses[@(screenIndex)] = screenAddrs;
  }
  return screenAddrs;
}

- (void)setAddresses:(NSMutableArray *)addresses forScreenIndex:(NSInteger)screenIndex {
  if (addresses) {
    self.screenAddresses[@(screenIndex)] = addresses;
  } else {
    [self.screenAddresses removeObjectForKey:@(screenIndex)];
  }
}

- (NSMutableArray *)effectiveAddressesForScreenIndex:(NSInteger)screenIndex {
  if (!self.perScreenMode) {
    return self.addresses;
  }

  NSMutableArray *screenAddrs = self.screenAddresses[@(screenIndex)];
  if (screenAddrs.count > 0) {
    return screenAddrs;
  }

  // Fallback to global list if no per-screen config
  return self.addresses;
}

- (void)distributeGlobalAddressesToAllScreens {
  NSInteger count = [WVSSScreenIdentifier numberOfScreens];
  for (NSInteger i = 0; i < count; i++) {
    NSMutableArray *copy = [NSMutableArray array];
    for (WVSSAddress *addr in self.addresses) {
      [copy addObject:[WVSSAddress addressWithURL:addr.url duration:addr.duration]];
    }
    self.screenAddresses[@(i)] = copy;
  }
  WVSSLog(@"Distributed global addresses to %ld screens", (long)count);
}

#pragma mark - Remote Fetch

- (void)fetchIfNeeded {
  if (!self.shouldFetchAddressList) return;

  NSString *addressFetchURL = self.addressListURL;
  if (!addressFetchURL.length) return;
  if (!([addressFetchURL hasPrefix:@"http://"] || [addressFetchURL hasPrefix:@"https://"])) return;

  _fetcher = [[WVSSAddressListFetcher alloc] initWithURL:addressFetchURL];
  _fetcher.delegate = self;
}

#pragma mark - WVSSAddressListFetcherDelegate

- (void)addressListFetcher:(WVSSAddressListFetcher *)fetcher didFailWithError:(NSError *)error {
  WVSSLog(@"Encountered issue: %@", error.localizedDescription);
}

- (void)addressListFetcher:(WVSSAddressListFetcher *)fetcher
        didFinishWithArray:(NSArray *)response {
  [self.addresses removeAllObjects];
  [self.addresses addObjectsFromArray:response];
}

@end
