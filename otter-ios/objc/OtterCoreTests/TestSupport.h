#import <XCTest/XCTest.h>
#import "JSONValue.h"

#define expect(actual, expected) XCTAssertEqualObjects((actual), (expected))
#define expectValue(actual, expected) XCTAssertEqualObjects((actual), (expected))

#define assertNumberInt(value, expectedInt) \
    do { \
        JSONNumber *__number = [(value) number]; \
        if (__number == nil) { \
            XCTFail(@"expected Number, got %@", (value)); \
        } else { \
            XCTAssertEqual((long long)(expectedInt), (long long)__number.intValue); \
        } \
    } while (0)

#define assertNumberDouble(value, expectedDouble) \
    do { \
        JSONNumber *__number = [(value) number]; \
        if (__number == nil) { \
            XCTFail(@"expected Number, got %@", (value)); \
        } else { \
            XCTAssertEqualWithAccuracy((double)(expectedDouble), __number.doubleValue, 0); \
        } \
    } while (0)

#define assertFails(message, ...) \
    do { \
        NSError *__otError = nil; \
        void (^__otBlock)(NSError **) = __VA_ARGS__; \
        __otBlock(&__otError); \
        if (__otError == nil) { \
            XCTFail(@"期望抛出 TemplateParseException：%@", (message)); \
        } else { \
            XCTAssertEqualObjects(TemplateParseExceptionDomain, __otError.domain); \
            XCTAssertEqualObjects((message), __otError.localizedDescription); \
        } \
    } while (0)

#define assertFailsPrefix(prefix, ...) \
    do { \
        NSError *__otError = nil; \
        void (^__otBlock)(NSError **) = __VA_ARGS__; \
        __otBlock(&__otError); \
        if (__otError == nil) { \
            XCTFail(@"期望抛出 TemplateParseException：%@", (prefix)); \
        } else { \
            XCTAssertEqualObjects(TemplateParseExceptionDomain, __otError.domain); \
            XCTAssertTrue([__otError.localizedDescription hasPrefix:(prefix)], @"%@", __otError.localizedDescription); \
        } \
    } while (0)

FOUNDATION_EXPORT BOOL OTIsDirectory(NSString *path);
FOUNDATION_EXPORT BOOL OTIsFile(NSString *path);
FOUNDATION_EXPORT NSURL *OTFirstExistingDirectory(NSArray<NSString *> *relatives);
