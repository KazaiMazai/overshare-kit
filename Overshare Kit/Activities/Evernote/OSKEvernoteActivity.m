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
#import <EvernoteSDK.h>
#import "NSString+XMLAdditions.h"
#import "NSString+HTMLParsing.h"
#import "NSData+APCommonCrypto.h"
#import "OSKApplicationCredential.h"

#define kENMLPrefix @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\"><en-note style=\"word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;\">"
#define kENMLSuffix @"</en-note>"

@interface OSKEvernoteActivity()

@property (strong, nonatomic) NSTimer *authenticationTimeoutTimer;
@property (assign, nonatomic) BOOL authenticationTimedOut;
@property (copy, nonatomic) OSKGenericAuthenticationCompletionHandler completionHandler;

@end

@implementation OSKEvernoteActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        OSKApplicationCredential *credentials = [self.class applicationCredential];
        if (credentials) {
            [EvernoteSession setSharedSessionHost:BootstrapServerBaseURLStringUS consumerKey:credentials.applicationKey consumerSecret:credentials.applicationSecret];
        }
    }
    return self;
}

- (void)dealloc {
    
}

#pragma mark - Generic Authentication

- (BOOL)isAuthenticated {
   return [EvernoteSession sharedSession].isAuthenticated;
}

- (void) logoutWithGenericAuthentication {
    if([EvernoteSession sharedSession].isAuthenticated){
        [[EvernoteSession sharedSession] logout];
    }
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
            if (completion && weakSelf.authenticationTimedOut == NO) {
                [weakSelf cancelAuthenticationTimeoutTimer];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
                
            }
        } else {
            if (completion && weakSelf.authenticationTimedOut == NO) {
                [weakSelf cancelAuthenticationTimeoutTimer];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, error);
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
    OSKApplicationCredential *credentials = [self.class applicationCredential];
    if (credentials) {
        return YES;
    }
    return NO;
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
        image = [UIImage imageNamed:@"Evernote-Icon-60.png"];
    } else {
        image = [UIImage imageNamed:@"Evernote-Icon-76.png"];
    }
    return image;
}

+ (UIImage *)settingsIcon {
    return [UIImage imageNamed:@"Evernote-Icon-29.png"];
}

+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_Generic;
}

+ (BOOL)requiresApplicationCredential {
    return YES;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    return ([self readLaterItem].url != nil && [EvernoteSession sharedSession].isAuthenticated);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    __weak OSKEvernoteActivity *weakSelf = self;
    
    NSString *title = [self readLaterItem].title;
    NSString *strURL = [[self readLaterItem].url absoluteString];
    NSString *strOptionalURL = [[self readLaterItem].optionalUrl absoluteString];
    NSString *text = [self readLaterItem].body;
    NSString *description = [[self readLaterItem].description stringByEscapingCriticalXMLEntities];
    NSArray *images = [self readLaterItem].images;
    NSMutableArray *resources = [NSMutableArray array];
    EDAMNoteAttributes *atr =[[EDAMNoteAttributes alloc] init];
 
    NSMutableString* contentStr = [[NSMutableString alloc] initWithString:kENMLPrefix];
    
    // Evernote doesn't accept unenencoded ampersands
    strURL = [strURL encode];
  
    if(title.length>0) {
        [contentStr appendFormat:@"<h1>%@</h1>",[title stringByEscapingForHTML]];
    }
    
    if(text.length>0 ) {
        [contentStr appendFormat:@"<p>%@</p>", [text flattenHTMLPreservingLineBreaks:YES]];
    } else {
        [contentStr appendString:description];
    }
    
    if(strURL.length>0) {
        [contentStr appendFormat:@"<p><a href=\"%@\">%@</a></p>",strURL,strURL ];
        atr.sourceURL = strURL;
    }
    
    if(strOptionalURL.length>0) {
        [contentStr appendFormat:@"<p><a href=\"%@\">%@</a></p>",strOptionalURL,strOptionalURL ];
    }
    
    for (UIImage *image in images) {
        EDAMResource *img = [[EDAMResource alloc] init];
        NSData *rawimg = UIImageJPEGRepresentation(image, 0.6);
        EDAMData *imgd = [[EDAMData alloc] initWithBodyHash:rawimg size:(int32_t)[rawimg length] body:rawimg];
        [img setData:imgd];
        [img setRecognition:imgd];
        [img setMime:@"image/jpeg"];
        [resources addObject:img];
        [contentStr appendString:[NSString stringWithFormat:@"<p>%@</p>",[self enMediaTagWithResource:img width:image.size.width height:image.size.height]]];
    }
    
    [contentStr appendString:kENMLSuffix];
    
    for(EDAMResource *res in resources) {
        if(![res dataIsSet]&&[res attributesIsSet]&&res.attributes.sourceURL.length>0&&[res.mime isEqualToString:@"image/jpeg"]) {
            @try {
                NSData *rawimg = [NSData dataWithContentsOfURL:[NSURL URLWithString:res.attributes.sourceURL]];
                UIImage *img = [UIImage imageWithData:rawimg];
                if(img) {
                    EDAMData *imgd = [[EDAMData alloc] initWithBodyHash:rawimg size:(int32_t)[rawimg length] body:rawimg];
                    [res setData:imgd];
                    [res setRecognition:imgd];
                    contentStr = [NSMutableString stringWithString:[contentStr stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"<img src=\"%@\" />",res.attributes.sourceURL] withString:[self enMediaTagWithResource:res width:img.size.width height:img.size.height]]];
                }
            }
            @catch (NSException * e) {
                NSLog(@"Evernote sharing resources parsing exceprion");
            }
        }
    }
    
    
    EDAMNote *note = [[EDAMNote alloc] initWithGuid:nil title:title content:contentStr contentHash:nil contentLength:(int32_t)contentStr.length created:0 updated:0 deleted:0 active:YES updateSequenceNum:0 notebookGuid:nil tagGuids:nil resources:resources attributes:atr tagNames:nil];
    
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (completion) {
            completion(weakSelf, NO, nil);
        }
    }];
    
    [[EvernoteNoteStore noteStore] createNote:note success:^(EDAMNote *note) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(weakSelf, YES, nil);
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
            });
        }
    } failure:^(NSError *error) {
        NSLog(@"Ever error: %@",error);
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

#pragma mark - Evernote utils

- (NSString *)enMediaTagWithResource:(EDAMResource *)src width:(CGFloat)width height:(CGFloat)height {
	NSString *sizeAtr = width > 0 && height > 0 ? [NSString stringWithFormat:@"height=\"%.0f\" width=\"%.0f\" ",height,width]:@"";
	return [NSString stringWithFormat:@"<en-media type=\"%@\" %@hash=\"%@\"/>",src.mime,sizeAtr,[src.data.body ap_MD5HashString]];
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
        __weak OSKEvernoteActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"OSKEvernoteActivity" code:408 userInfo:@{NSLocalizedFailureReasonErrorKey:@"Evernote authentication timed out."}];
            weakSelf.completionHandler(NO, error);
        });
    }
}
@end
