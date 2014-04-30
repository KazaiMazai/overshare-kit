//
//  OSKVkontakteActivity.m
//  OvershareKit
//
//  Created by Kazakov Sergey on 30.04.14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKVkontakteActivity.h"
#import "OSKPresentationManager.h"
#import "OSKShareableContentItem.h"
#import <VKSdk.h>

@interface OSKVkontakteActivity() <VKSdkDelegate>

@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKGenericAuthenticationCompletionHandler completionHandler;

@end

@implementation OSKVkontakteActivity


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
    return ([VKSdk isLoggedIn] || [VKSdk wakeUpSession]);
}

- (void)authenticate:(OSKGenericAuthenticationCompletionHandler)completion {
    [self setCompletionHandler:completion];
    [self startAuthenticationTimeoutTimer];
    [VKSdk authorize:@[VK_PER_WALL,VK_PER_PHOTOS]];
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
    return @"Vkontakte";
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
    __weak OSKVkontakteActivity *weakSelf = self;
    
    NSString *content = [self sharableItem].text;
    NSArray *images = [self sharableItem].images;
   
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    
    if (images.count == 0) {
        
        NSDictionary *params = @{VK_API_FRIENDS_ONLY:@(0),
                                VK_API_OWNER_ID:[VKSdk getAccessToken].userId,
                                VK_API_MESSAGE:content};
        
        VKRequest *post = [[VKApi wall] post:params];
        [post executeWithResultBlock: ^(VKResponse *response) {
            NSNumber * postId = response.json[@"post_id"];
           /* [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://vk.com/wall%@_%@", [VKSdk getAccessToken].userId, postId]]];*/
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(weakSelf, YES, nil);
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }
            
        } errorBlock: ^(NSError *error) {
            NSLog(@"Error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, (error == nil), error);
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
            });
        }];
    } else {
        UIImage *image = [images objectAtIndex:0];
        NSString *userId = [VKSdk getAccessToken].userId;
        VKRequest *request = [VKApi uploadWallPhotoRequest:image parameters:[VKImageParameters jpegImageWithQuality:1.f] userId:[userId integerValue] groupId:0];
        [request executeWithResultBlock: ^(VKResponse *response) {
            VKPhoto *photoInfo = [(VKPhotoArray*)response.parsedModel objectAtIndex:0];
            NSString *photoAttachment = [NSString stringWithFormat:@"photo%@_%@", photoInfo.owner_id, photoInfo.id];
            NSDictionary *params = @{ VK_API_ATTACHMENTS : photoAttachment,
                                VK_API_FRIENDS_ONLY : @(0),
                                VK_API_OWNER_ID : userId,
                                VK_API_MESSAGE : [NSString stringWithFormat:@"%@",content]};
            VKRequest *post = [[VKApi wall] post:params];
            [post executeWithResultBlock: ^(VKResponse *response) {
                NSNumber * postId = response.json[@"post_id"];
               /* [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://vk.com/wall%@_%@", [VKSdk getAccessToken].userId, postId]]];*/
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(weakSelf, YES, nil);
                        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                    });
                }
                
            } errorBlock: ^(NSError *error) {
                NSLog(@"Error: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(weakSelf, (error == nil), error);
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }];
        } errorBlock: ^(NSError *error) {
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

#pragma mark - VKsdkProtocol

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError {
    
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken {
    
}

- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError {
    [self cancelAuthenticationTimeoutTimer];
    __weak OSKVkontakteActivity *weakSelf = self;
    if (weakSelf.completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKVkontakteActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Vkontakte authentication fail."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller {
    
}

- (void)vkSdkReceivedNewToken:(VKAccessToken *)newToken {
    __weak OSKVkontakteActivity *weakSelf = self;
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
        __weak OSKVkontakteActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKVkontakteActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Vkontakte authentication timed out."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}

@end
