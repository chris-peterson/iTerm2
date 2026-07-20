//
//  iTermStatusBarTextComponent.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/29/18.
//

#import <Foundation/Foundation.h>
#import "iTermStatusBarBaseComponent.h"

NS_ASSUME_NONNULL_BEGIN

// A base class for components that show text.
// This class only knows how to show static text. Subclasses may choose to configure it by overriding
// stringValue, attributedStringValue, statusBarComponentUpdateCadence, and statusBarComponentUpdate.
@interface iTermStatusBarTextComponent : iTermStatusBarBaseComponent

@property (nonatomic, readonly, nullable) NSArray<NSString *> *stringVariants;
@property (nonatomic, readonly) NSTextField *textField;

- (CGFloat)widthForString:(NSString *)string;
- (void)updateTextFieldIfNeeded;
- (NSTextField *)newTextField;
- (nullable NSString *)stringValueForCurrentWidth;

// Parse `[display](url)` markdown into an attributed string with clickable
// NSLinkAttributeName link spans (STATUS-BAR markdown links); literal text and
// each link's display text take `color`/`font`. nil when there are no links.
// A class method so the parse is unit-testable without a live component.
+ (nullable NSAttributedString *)it_attributedStringWithLinksFromString:(NSString *)string
                                                                  color:(NSColor *)color
                                                                   font:(NSFont *)font
    NS_SWIFT_NAME(attributedStringWithMarkdownLinks(from:color:font:));

@end

NS_ASSUME_NONNULL_END
