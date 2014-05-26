//
//  NSData+APCommonCrypto.h
//
//  Created by Andrew Vyazovoy on 15.10.13.
//  Copyright (c) 2013 Applifto Inc. All rights reserved.
//

@import Foundation;

#import <CommonCrypto/CommonCrypto.h>

@interface NSData (APCommonCrypto)

- (NSString *)ap_MD2HashString;
- (NSString *)ap_MD4HashString;
- (NSString *)ap_MD5HashString;
- (NSString *)ap_SHA1HashString;
- (NSString *)ap_SHA224HashString;
- (NSString *)ap_SHA256HashString;
- (NSString *)ap_SHA384HashString;
- (NSString *)ap_SHA512HashString;

@end
