//
//  iTermClickableTextField.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 12/21/19.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface iTermClickableTextField : NSTextField

- (void)openURL:(NSURL *)url;

// URL of the link under `point` (view coordinates), or nil. Exposed so a
// caller that intercepts the click itself can reuse the hit-test.
- (nullable NSURL *)urlAtPoint:(NSPoint)point;

@end

NS_ASSUME_NONNULL_END
