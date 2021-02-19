//
//  MFStructDeclareTable.h
//  MangoFix
//
//  Created by jerry.yong on 2018/2/24.
//  Copyright © 2018年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFStructDeclare.h"

NS_ASSUME_NONNULL_BEGIN

@interface YTXMFStructDeclareTable : NSObject
+ (instancetype)shareInstance;

- (void)addStructDeclare:(YTXMFStructDeclare *)structDeclare;
- (nullable YTXMFStructDeclare *)getStructDeclareWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
