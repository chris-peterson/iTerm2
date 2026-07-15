//
//  iTermStatusBarTextComponent.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/29/18.
//

#import "iTermStatusBarTextComponent.h"

#import "DebugLogging.h"
#import "iTermClickableTextField.h"
#import "iTermStatusBarSetupKnobsViewController.h"
#import "iTermTuple.h"
#import "NSArray+iTerm.h"
#import "NSColor+iTerm.h"
#import "NSDictionary+iTerm.h"
#import "NSObject+iTerm.h"
#import "NSStringITerm.h"

NS_ASSUME_NONNULL_BEGIN

@implementation iTermStatusBarTextComponent {
    NSTextField *_textField;
    NSTextField *_measuringField;
    NSString *_longestStringValue;
}

- (NSArray<iTermStatusBarComponentKnob *> *)statusBarComponentKnobs {
    iTermStatusBarComponentKnob *textColorKnob =
        [[iTermStatusBarComponentKnob alloc] initWithLabelText:@"Text Color:"
                                                          type:iTermStatusBarComponentKnobTypeColor
                                                   placeholder:nil
                                                  defaultValue:nil
                                                           key:iTermStatusBarSharedTextColorKey];
    iTermStatusBarComponentKnob *backgroundColorKnob =
        [[iTermStatusBarComponentKnob alloc] initWithLabelText:@"Background Color:"
                                                          type:iTermStatusBarComponentKnobTypeColor
                                                   placeholder:nil
                                                  defaultValue:nil
                                                           key:iTermStatusBarSharedBackgroundColorKey];
    iTermStatusBarComponentKnob *fontKnob =
        [[iTermStatusBarComponentKnob alloc] initWithLabelText:@"Custom Font"
                                                          type:iTermStatusBarComponentKnobTypeFont
                                                   placeholder:nil
                                                  defaultValue:nil
                                                           key:iTermStatusBarSharedFontKey];

    return [@[ textColorKnob, backgroundColorKnob, fontKnob, [super statusBarComponentKnobs], [self minMaxWidthKnobs]] flattenedArray];
}

- (NSFont *)font {
    NSDictionary *knobValues = self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
    NSString *name = knobValues[iTermStatusBarSharedFontKey];
    NSFont *font = nil;
    if (name.length > 0) {
        font = [name fontValueWithLigaturesEnabled:YES];
    }
    if (!font) {
        return self.advancedConfiguration.font ?: [iTermStatusBarAdvancedConfiguration defaultFont];
    }
    return font;
}

- (NSTextField *)newTextField {
    // iTermClickableTextField opens the URL of the NSLinkAttributeName span
    // under a click (STATUS-BAR markdown links, below); with no link attrs it
    // behaves exactly like NSTextField, so it's safe for every text component.
    NSTextField *textField = [[iTermClickableTextField alloc] initWithFrame:NSZeroRect];
    textField.font = [self font];
    textField.drawsBackground = NO;
    textField.bordered = NO;
    textField.editable = NO;
    textField.selectable = NO;
    textField.lineBreakMode = NSLineBreakByTruncatingTail;

    textField.textColor = self.textColor;
    textField.font = self.font;
    textField.backgroundColor = self.backgroundColor;
    textField.drawsBackground = (self.backgroundColor.alphaComponent > 0);

    return textField;
}

- (BOOL)statusBarComponentIsEmpty {
    return [[self longestStringValue] length] == 0;
}

- (NSColor *)textColor {
    NSDictionary *knobValues = self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
    return [knobValues[iTermStatusBarSharedTextColorKey] colorValue] ?: ([self defaultTextColor] ?: [self.delegate statusBarComponentDefaultTextColor]);
}

- (NSColor *)backgroundColor {
    NSDictionary *knobValues = self.configuration[iTermStatusBarComponentConfigurationKeyKnobValues];
    return [knobValues[iTermStatusBarSharedBackgroundColorKey] colorValue] ?: [super statusBarBackgroundColor];
}

- (BOOL)shouldUpdateValue:(NSString *)proposed inField:(NSTextField *)textField {
    const BOOL textFieldHasString = textField.stringValue.length > 0;
    const BOOL iHaveString = proposed.length > 0;

    if (textFieldHasString != iHaveString) {
        DLog(@"%@ updating because nilness changed. textfield=%@ proposed=%@", self, textField.stringValue, proposed);
        return YES;
    }
    if (textFieldHasString || iHaveString) {
        BOOL result = !([NSObject object:textField.stringValue isEqualToObject:proposed] &&
                        [NSObject object:textField.textColor isEqualToObject:self.textColor]);
        if (result) {
            DLog(@"%@ updating because %@ != %@", self, textField.stringValue, proposed);
        }
        return result;
    }
    
    return NO;
}

// Matches a markdown-style link `[display](url)`: a `[...]` immediately
// followed by a `(...)`, where the display can't contain `]` and the url can't
// contain `)`. Requiring `](` adjacent means incidental text like `[3] (main)`
// never matches — a link is opt-in, written as the exact `[display](url)` form.
+ (NSRegularExpression *)it_linkRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^)]+)\\)"
                                                          options:0
                                                            error:nil];
    });
    return regex;
}

// Parse `[display](url)` spans into an attributed string: literal text takes
// `color`/`font`, each link becomes its `display` text carrying
// NSLinkAttributeName (which iTermClickableTextField opens on click) plus a
// dotted underline. Returns nil when the string has no links, so callers with
// none keep the plain stringValue path unchanged (STATUS-BAR markdown links).
// A class method (color/font passed in) so the parse is unit-testable without a
// live component; the instance wrapper below supplies the component's own.
+ (nullable NSAttributedString *)it_attributedStringWithLinksFromString:(NSString *)string
                                                                  color:(NSColor *)color
                                                                   font:(NSFont *)font {
    if (string.length == 0) {
        return nil;
    }
    NSArray<NSTextCheckingResult *> *matches =
        [[self it_linkRegex] matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    if (matches.count == 0) {
        return nil;
    }
    NSDictionary *base = @{ NSForegroundColorAttributeName: color ?: [NSColor labelColor],
                            NSFontAttributeName: font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]] };
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSUInteger cursor = 0;
    for (NSTextCheckingResult *match in matches) {
        const NSRange full = match.range;
        if (full.location > cursor) {
            NSString *literal = [string substringWithRange:NSMakeRange(cursor, full.location - cursor)];
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:literal attributes:base]];
        }
        NSString *display = [string substringWithRange:[match rangeAtIndex:1]];
        NSURL *url = [NSURL URLWithString:[string substringWithRange:[match rangeAtIndex:2]]];
        NSMutableDictionary *attrs = [base mutableCopy];
        if (url) {
            attrs[NSLinkAttributeName] = url;
            attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle | NSUnderlinePatternDot);
        }
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:display attributes:attrs]];
        cursor = NSMaxRange(full);
    }
    if (cursor < string.length) {
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:[string substringFromIndex:cursor]
                                                                       attributes:base]];
    }
    return result;
}

- (nullable NSAttributedString *)it_attributedStringWithLinksFromString:(NSString *)string {
    return [[self class] it_attributedStringWithLinksFromString:string
                                                          color:self.textColor
                                                           font:self.font];
}

- (BOOL)setValueInField:(NSTextField *)textField compressed:(BOOL)compressed {
    textField.textColor = self.textColor;

    NSString *proposed;
    if (compressed) {
        proposed = [self stringValueForCurrentWidth];
    } else {
        proposed = [self longestStringValue];
    }

    NSAttributedString *linked = [self it_attributedStringWithLinksFromString:proposed];
    if (linked) {
        // Links can't be diffed cheaply through stringValue (which drops the
        // URLs), so set it every pass; the caller already gates how often this
        // runs. shouldUpdateValue is the plain-text fast path below.
        textField.attributedStringValue = linked;
    } else {
        if (![self shouldUpdateValue:proposed inField:textField]) {
            return NO;
        }
        textField.stringValue = proposed ?: @"";
    }

    if (textField.alignment == NSTextAlignmentRight && textField.superview) {
        [self statusBarComponentSizeView:textField toFitWidth:textField.superview.bounds.size.width];
    } else {
        [textField sizeToFit];
    }
    return YES;
}

- (void)setDelegate:(id<iTermStatusBarComponentDelegate> _Nullable)delegate {
    [super setDelegate:delegate];
    _textField.textColor = self.textColor;
}

- (NSTextField *)textField {
    if (!_textField) {
        _textField = [self newTextField];
        [self setValueInField:_textField compressed:YES];
    }
    return _textField;
}

- (void)updateTextFieldIfNeeded {
    [self setValueInField:_textField compressed:YES];

    NSString *longest = self.longestStringValue ?: @"";
    if (![longest isEqual:_longestStringValue]) {
        _longestStringValue = longest;
        DLog(@"%@: set longest string value to %@", self, longest);
        [self.delegate statusBarComponentPreferredSizeDidChange:self];
    }
}

- (nullable NSString *)stringValueForCurrentWidth {
    CGFloat currentWidth = _textField.frame.size.width;
    return [self stringForWidth:currentWidth];
}

- (nullable NSString *)longestStringValue {
    return [self stringForWidth:INFINITY];
}

- (NSArray<iTermTuple<NSString *,NSNumber *> *> *)widthStringTuples {
    return [self.stringVariants mapWithBlock:^id(NSString *anObject) {
        CGFloat width = [self widthForString:anObject];
        return [iTermTuple tupleWithObject:anObject andObject:@(width)];
    }];
}

- (nullable NSString *)stringForWidth:(CGFloat)width {
    NSArray<iTermTuple<NSString *,NSNumber *> *> *tuples = [self widthStringTuples];
    tuples = [tuples filteredArrayUsingBlock:^BOOL(iTermTuple<NSString *,NSNumber *> *anObject) {
        return ceil(anObject.secondObject.doubleValue) <= ceil(width);
    }];
    return [tuples maxWithBlock:^NSComparisonResult(iTermTuple<NSString *,NSNumber *> *obj1, iTermTuple<NSString *,NSNumber *> *obj2) {
        return [obj1.secondObject compare:obj2.secondObject];
    }].firstObject ?: @"";
}

- (CGFloat)statusBarComponentPreferredWidth {
    NSString *longest = [self longestStringValue];
    if (!longest) {
        return 0;
    }
    return [self widthForString:longest];
}

- (void)statusBarComponentSizeView:(NSView *)view toFitWidth:(CGFloat)width {
    NSTextField *textField = [NSTextField castFrom:view];
    [textField sizeToFit];
    CGFloat x = 0;
    if (textField.alignment == NSTextAlignmentRight) {
        x = textField.superview.frame.size.width - width;
    }
    DLog(@"Place text view %@ of width %@ at x=%@ in container of width %@", textField, @(width), @(x), @(textField.superview.frame.size.width));
    view.frame = NSMakeRect(x, 0, width, view.frame.size.height);
    if (view == _textField) {
        [self setValueInField:_textField compressed:YES];
    }
}

- (CGFloat)widthForString:(NSString *)string {
    if (!string) {
        return 0;
    }
    if (!_measuringField) {
        _measuringField = [self newTextField];
    }
    // Measure the rendered width — for a string with links that's the display
    // text (markdown stripped), not the raw `[display](url)` source.
    NSAttributedString *linked = [self it_attributedStringWithLinksFromString:string];
    if (linked) {
        _measuringField.attributedStringValue = linked;
    } else {
        _measuringField.stringValue = string;
        _measuringField.textColor = self.textColor;
    }
    [_measuringField sizeToFit];
    return [_measuringField frame].size.width;
}

- (CGFloat)statusBarComponentMinimumWidth {
    NSArray<iTermTuple<NSString *,NSNumber *> *> *tuples = [self widthStringTuples];
    NSNumber *number = [tuples minWithBlock:^NSComparisonResult(iTermTuple<NSString *,NSNumber *> *obj1, iTermTuple<NSString *,NSNumber *> *obj2) {
        return [obj1.secondObject compare:obj2.secondObject];
    }].secondObject;
    return number.doubleValue;
}

- (NSColor * _Nullable)statusBarTextColor {
    return [self textColor];
}

- (NSColor *)statusBarBackgroundColor {
    return [self backgroundColor];
}

- (nullable NSString *)statusBarComponentCopyableString {
    return [self longestStringValue];
}

- (CGFloat)statusBarComponentVerticalOffset {
    const CGFloat containerHeight = _textField.superview.bounds.size.height;
    const CGFloat capHeight = _textField.font.capHeight;
    const CGFloat descender = _textField.font.descender - _textField.font.leading;  // negative (distance from bottom of bounding box to baseline)
    const CGFloat frameY = (containerHeight - _textField.frame.size.height) / 2;
    const CGFloat origin = containerHeight / 2.0 - frameY + descender - capHeight / 2.0;
    return origin;
}

#pragma mark - iTermStatusBarComponent

- (NSView *)statusBarComponentView {
    return self.textField;
}

- (void)statusBarComponentUpdate {
    [self updateTextFieldIfNeeded];
}

- (void)statusBarComponentWidthDidChangeTo:(CGFloat)newWidth {
    [self updateTextFieldIfNeeded];
}

- (void)statusBarDefaultTextColorDidChange {
    [self updateTextFieldIfNeeded];
}

@end

NS_ASSUME_NONNULL_END
