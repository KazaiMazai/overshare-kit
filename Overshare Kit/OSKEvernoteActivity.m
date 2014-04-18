//
//  APEvernoteOSKActivity.m
//  Applifto
//
//  Created by kazai_mazai on 17.04.14.
//  Copyright (c) 2014 Applifto Inc. All rights reserved.
//

#import "OSKEvernoteActivity.h"
#import "OSKActivity.h"

#import "OSKPresentationManager.h"
#import "OSKShareableContentItem.h"

@interface OSKEvernoteActivity()

@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKGenericAuthenticationCompletionHandler completionHandler;

@end

@implementation OSKEvernoteActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    
}

#pragma mark - Generic Authentication

- (BOOL)isAuthenticated {
   return [EvernoteSession sharedSession].isAuthenticated;
}

- (void)authenticate:(OSKGenericAuthenticationCompletionHandler)completion {
    
    EvernoteSession *session = [EvernoteSession sharedSession];
    UIViewController *viewController = [[OSKPresentationManager sharedInstance] authenticationViewControllerForActivity:self];
    [self setCompletionHandler:completion];
    [self startAuthenticationTimeoutTimer];
    __weak OSKEvernoteActivity *weakSelf = self;
    
    [session authenticateWithViewController:viewController completionHandler:^(NSError *error) {
        if (error || !session.isAuthenticated) {
            // authentication failed :(
            // show an alert, etc
            // ...
        } else {
            if (completion && weakSelf.authenticationTimedOut == NO) {
                [weakSelf cancelAuthenticationTimeoutTimer];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion((error == nil), error);
                });

            }
        } 
    }];
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_ReadLater;
}

+ (BOOL)isAvailable {
    return  YES;
}

+ (NSString *)activityType {
    return OSKActivityType_SDK_Evernote;
}

+ (NSString *)activityName {
    return @"Evernote";
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"Pocket-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Pocket-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"Pocket-Icon-29.png"];
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
    return  ([self readLaterItem].url != nil && [EvernoteSession sharedSession].isAuthenticated);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKEvernoteActivity *weakSelf = self;
    EDAMNote *newNote = [[EDAMNote alloc] init];
    newNote.content = [self readLaterItem].url.path;
    newNote.title = [self readLaterItem].title;
    newNote.contentLength = (int)[self readLaterItem].url.path.length;
    
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    [[EvernoteNoteStore noteStore] createNote:newNote success:^(EDAMNote *note) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, YES, nil);
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
            });
        }
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(weakSelf, (error == nil), error);
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        });
    }];
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark - Convenience

- (OSKReadLaterContentItem *)readLaterItem {
    return (OSKReadLaterContentItem *)self.contentItem;
}

#pragma mark - Authentication Timeout

- (void)startAuthenticationTimeoutTimer {
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:60*2]
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
        __weak OSKEvernoteActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKEvernoteActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Evernote authentication timed out."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}
@end
