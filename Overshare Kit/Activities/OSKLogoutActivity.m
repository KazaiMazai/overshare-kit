//
//  OSKLogoutActivity.m
//  OvershareKit
//
//  Created by Kazakov Sergey on 28.05.14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKLogoutActivity.h"
#import "OSKActivitiesManager.h"

#import "OSKActivity.h"

#import "OSKPresentationManager.h"
#import "OSKShareableContentItem.h"

@implementation OSKLogoutActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}


#pragma mark - Generic Authentication

- (BOOL)isAuthenticated {
    return YES;
}

- (void) authenticate:(OSKGenericAuthenticationCompletionHandler)completion {
    if (completion) {
        completion(YES, nil);
    }
}

- (void) logoutWithGenericAuthentication {
    
}


#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_Logout;
}

+ (BOOL)isAvailable {
    return  YES;
}

+ (NSString *)activityType {
    return OSKActivityType_Logout;
}

+ (NSString *)activityName {
    return @"Logout";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"logout-60.png"];
    } else {
        image = [UIImage imageNamed:@"logout-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"logout-29.png"];
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
    return YES;
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    
    [[OSKActivitiesManager sharedInstance] logoutFromCurrentActivities];
    __weak OSKLogoutActivity *weakSelf = self;
    completion(weakSelf, YES, nil);
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}





@end
