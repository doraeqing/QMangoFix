//
//  MFFunctionDefinition.h
//  MangoFix
//
//  Created by jerry.yong on 2017/11/16.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFTypeSpecifier.h"
#import "YTXMFExpression.h"
#import "YTXMFStatement.h"
@class YTXMFBlockBody;
@class MFMethodDefinition;

@interface MFParameter:NSObject

@property (strong, nonatomic) YTXMFTypeSpecifier *type;
@property (copy, nonatomic) NSString *name;
@property (assign, nonatomic) NSUInteger lineNumber;

@end

typedef NS_ENUM(NSUInteger,MFFunctionDefinitionKind) {
	MFFunctionDefinitionKindMethod,
	MFFunctionDefinitionKindBlock,
	MFFunctionDefinitionKindFunction
};

@interface YTXMFFunctionDefinition: NSObject
@property (assign, nonatomic) NSUInteger lineNumber;
@property (strong, nonatomic) YTXMFTypeSpecifier *returnTypeSpecifier;
@property (assign, nonatomic) MFFunctionDefinitionKind kind;
@property (copy, nonatomic) NSString *name;//or selecor
@property (strong, nonatomic) NSArray<MFParameter *> *params;
@property (strong, nonatomic) YTXMFBlockBody *block;

@end
