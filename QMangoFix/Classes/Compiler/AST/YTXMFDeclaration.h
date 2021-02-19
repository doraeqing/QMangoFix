//
//  MFDeclaration.h
//  MangoFix
//
//  Created by jerry.yong on 2017/11/20.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MFDeclarationModifier.h"
@class YTXMFTypeSpecifier;
@class YTXMFExpression;

NS_ASSUME_NONNULL_BEGIN

@interface YTXMFDeclaration: NSObject

@property (assign, nonatomic) NSUInteger lineNumber;
@property (strong, nonatomic) YTXMFTypeSpecifier *type;
@property (assign,nonatomic) MFDeclarationModifier modifier;
@property (copy, nonatomic) NSString *name;
@property (strong, nonatomic,nullable) YTXMFExpression *initializer;

@end

NS_ASSUME_NONNULL_END
