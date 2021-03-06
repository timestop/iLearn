//
//  CacheHelper.m
//  iSearch
//
//  Created by lijunjie on 15/7/11.
//  Copyright (c) 2015年 Intfocus. All rights reserved.
//

#import "CacheHelper.h"
#import "const.h"
#import "FileUtils.h"

@implementation CacheHelper
/**
 *  读取本地缓存通知公告数据
 *
 *  @return 数据列表
 */
+ (NSMutableDictionary *)notifications {
    NSString *cachePath = [self cachePath:@"notification" Type:@"nil" ID:@"nil"];
    
    NSMutableDictionary *notificationDatas = [[NSMutableDictionary alloc] init];
    if([FileUtils checkFileExist:cachePath isDir:NO]) {
        notificationDatas = [FileUtils readConfigFile:cachePath];
    }
    
    return notificationDatas;
}
/**
 *  缓存服务器获取到的数据
 *
 *  @param notificationDatas 服务器获取到的数据
 */
+ (void)writeNotifications:(NSMutableDictionary *)notificationDatas {
    if(!notificationDatas) return;
    
    NSString *cachePath = [self cachePath:@"notification" Type:@"nil" ID:@"nil"];
    [FileUtils writeJSON:notificationDatas Into:cachePath];
}

/**
 *  课程包数据写入缓存文件
 *
 *  @param packages 课程包Name
 *  @param ID       课程包ID
 */
+ (void)writeCoursePackages:(NSMutableDictionary *)packages ID:(NSString *)ID {
    if(!packages)  return;
    
    NSString *cachePath = [self cachePath:@"course" Type:@"package" ID:ID];
    [FileUtils writeJSON:packages Into:cachePath];
}

/**
 *  读取缓存信息
 *
 *  @param ID 课程包ID
 *
 *  @return 课程包数据
 */
+ (NSMutableDictionary *)coursePackages:(NSString *)ID {
    NSString *cachePath = [self cachePath:@"course" Type:@"package" ID:ID];
  
    NSMutableDictionary *packages = [[NSMutableDictionary alloc] init];
    if([FileUtils checkFileExist:cachePath isDir:NO]) {
        packages = [FileUtils readConfigFile:cachePath];
    }
    
    return packages;
}

/**
 *  课程包内容写入缓存 文件
 *
 *  @param package 课程包内容
 *  @param ID      课程包ID
 */
+ (void)writeCoursePackageContent:(NSMutableDictionary *)package ID:(NSString *)ID {
    if(!package)  return;
    
    NSString *cachePath = [self cachePath:@"course" Type:@"content" ID:ID];
    [FileUtils writeJSON:package Into:cachePath];
}

/**
 *  缓存文件读取课程包内容
 *
 *  @param ID 课程包ID
 *
 *  @return 课程包内容
 */
+ (NSMutableDictionary *)coursePackageContent:(NSString *)ID {
    NSString *cachePath = [self cachePath:@"course" Type:@"content" ID:ID];
    
    NSMutableDictionary *package = [[NSMutableDictionary alloc] init];
    if([FileUtils checkFileExist:cachePath isDir:NO]) {
        package = [FileUtils readConfigFile:cachePath];
    }
    
    return package;
}


#pragma mark - asisstant methods
/**
 *  目录信息缓存文件文件路径;
 *  同一个分类ID,下载它的子分类集与子文档集通过两个不同的api链接，所以会有两个缓存文件。
 *
 *  @param type          notification,course_package
 *  @param contentType   category,slide
 *  @param ID     ID
 *
 *  @return cacheName
 */
+ (NSString *)cachePath:(NSString *)type Type:(NSString *)contentType ID:(NSString *)ID {
    NSString *cacheName = [NSString stringWithFormat:@"%@-%@-%@.cache",type, contentType, ID];
    NSString *cachePath = [FileUtils dirPath:CACHE_DIRNAME FileName:cacheName];
    return cachePath;
}
@end
