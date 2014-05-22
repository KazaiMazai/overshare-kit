//
//  NSString+HTML.h
//  OvershareKit
//
//  Created by Kazakov Sergey on 21.05.14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (HTMLParsing)

//methods& used in ShareKit to process html before sharing to evernote

- (NSString *)stringByEscapingForHTML;

- (NSString *)stringByEscapingForAsciiHTML;
 
- (NSString *)stringByUnescapingFromHTML;

- (NSString *)flattenHTMLPreservingLineBreaks:(BOOL) preserveLineBreaks;

- (NSString *)encode;

@end
