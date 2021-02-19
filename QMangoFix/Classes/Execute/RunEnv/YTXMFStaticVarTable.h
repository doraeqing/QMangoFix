//
//  MFStaticVarTable.h
//  MangoFix
//
//  Created by yongpengliang on 2019/6/7.
//  Copyright © 2019 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface YTXMFStaticVarTable : NSObject

+ (instancetype)shareInstance;

- (nullable YTXMFValue *)getStaticVarValueWithKey:(NSString *)key;
- (void)setStaticVarValue:(YTXMFValue *)value withKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
