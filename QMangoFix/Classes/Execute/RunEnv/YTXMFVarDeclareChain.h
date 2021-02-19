//
//  MFVarDeclareChain.h
//  MangoFix
//
//  Created by yongpengliang on 2019/5/1.
//  Copyright © 2019 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YTXMFVarDeclareChain : NSObject
@property (strong, nonatomic) YTXMFVarDeclareChain *next;

+ (instancetype)varDeclareChainWithNext:(YTXMFVarDeclareChain *)next;
- (BOOL)isInThisNote:(NSString *)indentifer;
- (BOOL)isInChain:(NSString *)indentifer;
- (void)addIndentifer:(NSString *)indentifer;

@end

NS_ASSUME_NONNULL_END
