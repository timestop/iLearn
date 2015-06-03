//
//  ExamUtil.h
//  iLearn
//
//  Created by Charlie Hung on 2015/5/28.
//  Copyright (c) 2015 intFocus. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExamUtil : NSObject

+ (NSArray*)loadExams;
+ (NSString*)jsonStringOfContent:(NSDictionary*)content;
+ (NSString*)titleFromContent:(NSDictionary*)content;
+ (NSString*)descFromContent:(NSDictionary*)content;
+ (NSInteger)expirationDateFromContent:(NSDictionary*)content;

+ (NSString*)examFolderPath;
+ (NSString*)examDBPathOfFile:(NSString*)fileName;

+ (void)parseContentIntoDB:(NSDictionary*)content;
+ (NSDictionary*)examContentFromDBFile:(NSString*)dbPath;

@end
