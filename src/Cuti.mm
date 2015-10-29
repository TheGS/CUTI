//
//  Cuti.m
//  count
//
//  Created by Baptiste Aubry on 22/10/15.
//  Copyright (c) 2015 Baptiste Aubry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "Cuti.h"
#include "cppunit/TestListener.h"
#include "cppunit/TestFailure.h"
#include "cppunit/TestResult.h"
#include "cppunit/TestResultCollector.h"
#include "cppunit/TestRunner.h"
#import <objc/runtime.h>

/**
 * Class prefix used for generated Objective-C class names.
 *
 * If a class name generated for a Cuti Test case conflicts with an existing
 * class the value of this variable can be changed to add a class prefix.
 */
static NSString * const GeneratedClassPrefix = @"";

/**
 * A Cuti listener that reports failures to XCTest.
 */
class XCTestListener : public CppUnit::TestListener {
public:
    XCTestListener(XCTestCase *testCase) :
    _testCase(testCase) {}
    
    virtual void addFailure(const CppUnit::TestFailure& testFailure) override {
        int lineNumber = testFailure.sourceLine().lineNumber();
        const char *fileName = testFailure.sourceLine().fileName().c_str();
        const char * message = testFailure.thrownException()->message().details().c_str();
        NSString *path = fileName ? [@(fileName) stringByStandardizingPath] : nil;
        NSString *description = @(message);
        [_testCase recordFailureWithDescription:description
                                         inFile:path
                                         atLine:(lineNumber >= 0 ? (NSUInteger)lineNumber : 0)
                                       expected:YES];
    }
    
private:
    XCTestCase *_testCase;
};

/**
 * Registers an XCTestCase subclass for each Cuti case.
 *
 * Generating these classes allows Cuti cases to be represented as peers
 * of standard XCTest suites and supports filtering of test runs to specific
 * Cuti cases or individual tests via Xcode.
 */
@interface CutiTestLoader : NSObject
@end

/**
 * Base class for the generated classes for Cuti cases.
 */
@interface CutiTestCase : XCTestCase
@end

@implementation CutiTestCase

/**
 * Associates generated Cuti Test classes with the test bundle.
 *
 * This affects how the generated test cases are represented in reports. By
 * associating the generated classes with a test bundle the Cuti Test cases
 * appear to be part of the same test bundle that this source file is compiled
 * into. Without this association they appear to be part of a bundle
 * representing the directory of an internal Xcode tool that runs the tests.
 */
+ (NSBundle *)bundleForClass {
    return [NSBundle bundleForClass:[CutiTestLoader class]];
}

/**
 * Implementation of +[XCTestCase testInvocations] that returns an array of test
 * invocations for each test method in the class.
 *
 * This differs from the standard implementation of testInvocations, which only
 * adds methods with a prefix of "test".
 */
+ (NSArray *)testInvocations {
    NSMutableArray *invocations = [NSMutableArray array];
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([self class], &methodCount);
    
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL sel = method_getName(methods[i]);
        NSMethodSignature *sig = [self instanceMethodSignatureForSelector:sel];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setSelector:sel];
        [invocations addObject:invocation];
    }
    
    free(methods);
    
    return invocations;
}

@end

static CppUnit::TestRunner cutiTestRunner;

/**
 * Runs a single test.
 */
static void RunTest(id self, SEL _cmd) {
    XCTestListener listener(self);
    
    NSString *testKey = [NSString stringWithFormat:@"%@", NSStringFromSelector(_cmd)];

    // Create the event manager and test controller
    CppUnit::TestResult controller;
    
    // Add a listener that colllects test result
    CppUnit::TestResultCollector result;
    controller.addListener(&result);
    
    // Add a listener
    controller.addListener(&listener);

    cutiTestRunner.run(controller, [testKey UTF8String]);
}

@implementation CutiTestLoader

/**
 * Performs registration of classes for Cuti Test cases after our bundle has
 * finished loading.
 *
 * This registration needs to occur before XCTest queries the runtime for test
 * subclasses, but after C++ static initializers have run so that all Cuti
 * Test cases have been registered. This is accomplished by synchronously
 * observing the NSBundleDidLoadNotification for our own bundle.
 */
+ (void)load {
    NSBundle *bundle = [NSBundle bundleForClass:self];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification object:bundle queue:nil usingBlock:^(NSNotification *notification) {
        [self registerTestClasses];
    }];
}

+ (void)registerTestClasses {
    NSMutableDictionary *testFilterMap = [NSMutableDictionary dictionary];
    NSCharacterSet *decimalDigitCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
    CppUnit::Test * cutiTests = CppUnit::TestFactoryRegistry::getRegistry().makeTest();
    cutiTestRunner.addTest(cutiTests);
    for (int testCaseIndex = 0; testCaseIndex < cutiTests->getChildTestCount(); testCaseIndex++) {
        const CppUnit::Test *testCase = cutiTests->getChildTestAt(testCaseIndex);
        NSString *testCaseName = @(testCase->getName().c_str());
        
        // For typed tests '/' is used to separate the parts of the test case name.
        NSArray *testCaseNameComponents = [testCaseName componentsSeparatedByString:@"/"];
        
     
        // Join the test case name components with '_' rather than '/' to create
        // a valid class name.
        NSString *className = [GeneratedClassPrefix stringByAppendingString:[testCaseNameComponents componentsJoinedByString:@"_"]];
        
        Class testClass = objc_allocateClassPair([CutiTestCase class], [className UTF8String], 0);
        NSAssert1(testClass, @"Failed to register Cuti Test class \"%@\", this class may already exist. The value of GeneratedClassPrefix can be changed to avoid this.", className);
        BOOL hasMethods = NO;
        
        for (int testIndex = 0; testIndex < testCase->getChildTestCount(); testIndex++) {
            const CppUnit::Test *test = testCase->getChildTestAt(testIndex);
            NSString *testName = @(test->getName().c_str());
            
            // Google Test allows test names starting with a digit, prefix these with an
            // underscore to create a valid method name.
            NSString *methodName = testName;
            if ([methodName length] > 0 && [decimalDigitCharacterSet characterIsMember:[methodName characterAtIndex:0]]) {
                methodName = [@"_" stringByAppendingString:methodName];
            }
            
            NSString *testKey = [NSString stringWithFormat:@"%@.%@", className, methodName];
            NSString *testFilter = [NSString stringWithFormat:@"%@.%@", testCaseName, testName];
            testFilterMap[testKey] = testFilter;
            
            SEL selector = sel_registerName([methodName UTF8String]);
            BOOL added = class_addMethod(testClass, selector, (IMP)RunTest, "v@:");
            NSAssert1(added, @"Failed to add Goole Test method \"%@\", this method may already exist in the class.", methodName);
            hasMethods = YES;
        }
        
        if (hasMethods) {
            objc_registerClassPair(testClass);
        } else {
            objc_disposeClassPair(testClass);
        }
    }
    
 //   GoogleTestFilterMap = testFilterMap;
}

@end