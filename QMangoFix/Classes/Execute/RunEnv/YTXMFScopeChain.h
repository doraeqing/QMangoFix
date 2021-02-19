//
//  ANEScopeChain.h
//  MangoFix
//
//  Created by jerry.yong on 2018/2/28.
//  Copyright © 2018年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
@class YTXMFValue;

NS_ASSUME_NONNULL_BEGIN
@interface YTXMFScopeChain: NSObject
@property (weak, nonatomic) id instance;
@property (strong, nonatomic) YTXMFScopeChain *next;

+ (instancetype)scopeChainWithNext:(YTXMFScopeChain *)next;
- (nullable YTXMFValue *)getValueWithIdentifier:(NSString *)identifier endScope:(nullable YTXMFScopeChain *)endScope;
- (nullable YTXMFValue *)getValueWithIdentifierInChain:(NSString *)identifier;
- (nullable YTXMFValue *)getValueWithIdentifier:(NSString *)identifer;
- (void)setValue:(YTXMFValue *)value withIndentifier:(NSString *)identier;
- (void)assignWithIdentifer:(NSString *)identifier value:(YTXMFValue *)value;
- (void)setMangoBlockVarNil;
@end
NS_ASSUME_NONNULL_END




