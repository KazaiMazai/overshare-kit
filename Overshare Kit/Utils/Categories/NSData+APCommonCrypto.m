//
//  NSData+APCommonCrypto.m
//
//  Created by Andrew Vyazovoy on 15.10.13.
//  Copyright (c) 2013 Applifto Inc. All rights reserved.
//

#import "NSData+APCommonCrypto.h"

typedef NS_ENUM(NSUInteger, APHashType) {
    APHashTypeMD2,
    APHashTypeMD4,
    APHashTypeMD5,
    APHashTypeSHA1,
    APHashTypeSHA224,
    APHashTypeSHA256,
    APHashTypeSHA384,
    APHashTypeSHA512
};

NS_INLINE NSString *APHexStringWithBytes(unsigned char *buffer, NSUInteger bufferLen) {
    if (!buffer || bufferLen == 0) {
        return nil;
    }
    unichar *hexRepresentation = malloc(sizeof(unichar) * (bufferLen * 2));
    static const unsigned char dictionary[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
    for (NSUInteger i = 0, k = 0; i < bufferLen; i++, k++) {
        uint8_t byte = buffer[i];
        hexRepresentation[k++] = dictionary[(byte & INT8_C(0xF0)) >> 4];
        hexRepresentation[k] = dictionary[byte & INT8_C(0x0F)];
    }
    NSString *resultString = [[NSString alloc] initWithCharactersNoCopy:hexRepresentation length:bufferLen * 2 freeWhenDone:YES];
    
    if (!resultString) {
        free(hexRepresentation);
    }
    
    return resultString;
}

NS_INLINE NSString *APHashString(APHashType hashType, NSData *data) {
    NSUInteger dataLength = [data length];
#if __LP64__
    
    if (dataLength > UINT32_MAX) {
        return nil;
    }
#endif
    
    if (dataLength == 0) {
        return nil;
    }
    NSUInteger hashLength;
    
    switch (hashType) {
        case APHashTypeMD2:
            hashLength = CC_MD2_DIGEST_LENGTH;
            break;
            
        case APHashTypeMD4:
            hashLength = CC_MD4_DIGEST_LENGTH;
            break;
            
        case APHashTypeMD5:
            hashLength = CC_MD5_DIGEST_LENGTH;
            break;
            
        case APHashTypeSHA1:
            hashLength = CC_SHA1_DIGEST_LENGTH;
            break;
            
        case APHashTypeSHA224:
            hashLength = CC_SHA224_DIGEST_LENGTH;
            break;
            
        case APHashTypeSHA256:
            hashLength = CC_SHA256_DIGEST_LENGTH;
            break;
            
        case APHashTypeSHA384:
            hashLength = CC_SHA384_DIGEST_LENGTH;
            break;
            
        case APHashTypeSHA512:
            hashLength = CC_SHA512_DIGEST_LENGTH;
            break;
            
        default:
            return nil;
            break;
    }
    unsigned char hashBuffer[hashLength];
    
    switch (hashType) {
        case APHashTypeMD2:
            hashLength = CC_MD2_DIGEST_LENGTH;
            CC_MD2([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeMD4:
            CC_MD4([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeMD5:
            CC_MD5([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeSHA1:
            CC_SHA1([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeSHA224:
            CC_SHA224([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeSHA256:
            CC_SHA256([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeSHA384:
            CC_SHA384([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        case APHashTypeSHA512:
            CC_SHA512([data bytes], (CC_LONG)dataLength, hashBuffer);
            break;
            
        default:
            return nil;
            break;
    }
    
    return APHexStringWithBytes(hashBuffer, hashLength);
}

@implementation NSData (APCommonCrypto)

- (NSString *)ap_MD2HashString {
    return APHashString(APHashTypeMD2, self);
}

- (NSString *)ap_MD4HashString {
    return APHashString(APHashTypeMD4, self);
}

- (NSString *)ap_MD5HashString {
    return APHashString(APHashTypeMD5, self);
}

- (NSString *)ap_SHA1HashString {
    return APHashString(APHashTypeSHA1, self);
}

- (NSString *)ap_SHA224HashString {
    return APHashString(APHashTypeSHA224, self);
}

- (NSString *)ap_SHA256HashString {
    return APHashString(APHashTypeSHA256, self);
}

- (NSString *)ap_SHA384HashString {
    return APHashString(APHashTypeSHA384, self);
}

- (NSString *)ap_SHA512HashString {
    return APHashString(APHashTypeSHA512, self);
}

@end
