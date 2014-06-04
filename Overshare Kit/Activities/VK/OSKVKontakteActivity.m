//
//  OSKVkontakteActivity.m
//  OvershareKit
//
//  Created by Kazakov Sergey on 30.04.14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKVKontakteActivity.h"
#import "OSKPresentationManager.h"
#import "OSKShareableContentItem.h"
#import <VKSdk.h>

@interface OSKVKontakteActivity() <VKSdkDelegate>

@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKGenericAuthenticationCompletionHandler completionHandler;

@end

@implementation OSKVKontakteActivity


- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        [VKSdk instance].delegate = self;
    }
    return self;
}

- (void)dealloc {
    
}

#pragma mark - Generic Authentication

- (BOOL)isAuthenticated {
    return [VKSdk isLoggedIn];
}

- (void)authenticate:(OSKGenericAuthenticationCompletionHandler)completion {
    [self setCompletionHandler:completion];
    [self startAuthenticationTimeoutTimer];

    [VKSdk authorize:@[VK_PER_WALL,VK_PER_PHOTOS] revokeAccess:YES];
}

- (void) logoutWithGenericAuthentication {
    [VKSdk forceLogout];
}
#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_ReadLater;
}

+ (BOOL)isAvailable {
    return YES;
}

+ (NSString *)activityType {
    return OSKActivityType_SDK_Vkontakte;
}

+ (NSString *)activityName {
    return @"VK";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"vk-icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"vk-icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"vk-icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_Generic;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    return ([self sharableItem].text.length > 0);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKVKontakteActivity *weakSelf = self;
    
    NSString *content = [self sharableItem].text;
    NSArray *images = [self sharableItem].images;
    NSString *url = [self sharableItem].url;
    
   
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    
    if (images.count == 0) {
        
        [self postText:content andLink:url success:^{
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(weakSelf, YES, nil);
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }
        } failure:^(NSError *error) {
            NSLog(@"Error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, (error == nil), error);
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
            });
        }];
        
    } else {
        
        [self postText:content andImage:[images objectAtIndex:0] success:^{
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(weakSelf, YES, nil);
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }
        } failure:^(NSError *error) {
            NSLog(@"Error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, (error == nil), error);
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
            });
        }];
    }
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark VK post methods


- (void) postText:(NSString *) text andImage: (UIImage *) image success:(void (^)())successBlock failure: (void (^)(NSError *error)) failureBlock {
    
    NSString *userId = [VKSdk getAccessToken].userId;
    VKRequest *request = [VKApi uploadWallPhotoRequest:image parameters:[VKImageParameters jpegImageWithQuality:1.f] userId:[userId integerValue] groupId:0];
    [request executeWithResultBlock: ^(VKResponse *response) {
        VKPhoto *photoInfo = [(VKPhotoArray*)response.parsedModel objectAtIndex:0];
        NSString *photoAttachment = [NSString stringWithFormat:@"photo%@_%@", photoInfo.owner_id, photoInfo.id];
        
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:@(0) forKey:VK_API_FRIENDS_ONLY];
        [params setObject: userId forKey:VK_API_OWNER_ID];
        [params setObject: photoAttachment forKey:VK_API_ATTACHMENTS];
        if (text.length > 0) {
            [params setObject: text forKey:VK_API_MESSAGE];
        }
        
        VKRequest *post = [[VKApi wall] post:params];
        [post executeWithResultBlock: ^(VKResponse *response) {
            if (successBlock) {
                successBlock();
            }
            
        } errorBlock: ^(NSError *error) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    } errorBlock: ^(NSError *error) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}


- (void) postText:(NSString *) text andLink: (NSString *) url success:(void (^)())successBlock failure: (void (^)(NSError *error)) failureBlock {
   
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@(0) forKey:VK_API_FRIENDS_ONLY];
    [params setObject:[VKSdk getAccessToken].userId forKey:VK_API_OWNER_ID];

    if (url.length > 0) {
        [params setObject: url forKey:VK_API_ATTACHMENTS];
    }
    
    if (text.length > 0) {
         [params setObject: text forKey:VK_API_MESSAGE];
    }
    
    VKRequest *post = [[VKApi wall] post:params];
    [post executeWithResultBlock: ^(VKResponse *response) {
        if (successBlock) {
            successBlock();
        }
        
    } errorBlock: ^(NSError *error) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

#pragma mark - VKsdkProtocol

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError {
    
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken {
    
}

- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError {
    [self cancelAuthenticationTimeoutTimer];
    __weak OSKVKontakteActivity *weakSelf = self;
    if (weakSelf.completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKVKontakteActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"VK authentication fail."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller {
    
}

- (void)vkSdkReceivedNewToken:(VKAccessToken *)newToken {
    __weak OSKVKontakteActivity *weakSelf = self;
    [weakSelf cancelAuthenticationTimeoutTimer];
    if (weakSelf.completionHandler && weakSelf.authenticationTimedOut == NO) {
       
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.completionHandler(YES,nil);
        });
        
    }
}



#pragma mark - Convenience

- (OSKVkontakteMicroblogPostContentItem *) sharableItem {
    return (OSKVkontakteMicroblogPostContentItem *)self.contentItem;
}

#pragma mark - Authentication Timeout

- (void)startAuthenticationTimeoutTimer {
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:60*5]
                                              interval:0
                                                target:self
                                              selector:@selector(authenticationTimedOut:)
                                              userInfo:nil
                                               repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)cancelAuthenticationTimeoutTimer {
    [_authenticationTimeoutTimer invalidate];
    _authenticationTimeoutTimer = nil;
}

- (void)authenticationTimedOut:(NSTimer *)timer {
    [self setAuthenticationTimedOut:YES];
    if (self.completionHandler) {
        __weak OSKVKontakteActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKVKontakteActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"VK authentication timed out."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}

@end
