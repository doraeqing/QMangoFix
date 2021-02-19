//
//  MFExpression.h
//  MangoFix
//
//  Created by jerry.yong on 2017/11/13.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YTXMFTypeSpecifier.h"
@class YTXMFFunctionDefinition;
@class YTXMFBlock;


typedef NS_ENUM(NSInteger, MFExpressionKind) {
	MF_BOOLEAN_EXPRESSION = 1,
	MF_INT_EXPRESSION,
	MF_U_INT_EXPRESSION,
	MF_DOUBLE_EXPRESSION,
	MF_STRING_EXPRESSION,
	MF_SELECTOR_EXPRESSION,
	MF_BLOCK_EXPRESSION,
	MF_IDENTIFIER_EXPRESSION,
	MF_TERNARY_EXPRESSION,
	MF_ASSIGN_EXPRESSION,
	MF_ADD_EXPRESSION,
	MF_SUB_EXPRESSION,
	MF_MUL_EXPRESSION,
	MF_DIV_EXPRESSION,
	MF_MOD_EXPRESSION,
	MF_EQ_EXPRESSION,
	MF_NE_EXPRESSION,
	MF_GT_EXPRESSION,
	MF_GE_EXPRESSION,
	MF_LT_EXPRESSION,
	MF_LE_EXPRESSION,
	MF_LOGICAL_AND_EXPRESSION,
	MF_LOGICAL_OR_EXPRESSION,
	MF_LOGICAL_NOT_EXPRESSION,
	NSC_NEGATIVE_EXPRESSION,
	MF_FUNCTION_CALL_EXPRESSION,
	MF_MEMBER_EXPRESSION,
	MF_NIL_EXPRESSION,
	MF_NULL_EXPRESSION,
	MF_SELF_EXPRESSION,
	MF_SUPER_EXPRESSION,
	MF_ARRAY_LITERAL_EXPRESSION,
	MF_DIC_LITERAL_EXPRESSION,
	MF_STRUCT_LITERAL_EXPRESSION,
	MF_SUB_SCRIPT_EXPRESSION,
	MF_INCREMENT_EXPRESSION,
	MF_DECREMENT_EXPRESSION,
	MF_AT_EXPRESSION,
    MF_C_FUNCTION_EXPRESSION,
    MF_GET_ADDRESS_EXPRESSION
};




@interface YTXMFExpression : NSObject

@property (assign, nonatomic) NSUInteger lineNumber;
@property (assign, nonatomic) MFExpressionKind expressionKind;
@property (assign, nonatomic) BOOL boolValue;
@property (assign, nonatomic) int64_t integerValue;
@property (assign, nonatomic) uint64_t  uintValue;
@property (assign, nonatomic) double doubleValue;
@property (assign, nonatomic) const char *cstringValue;
@property (copy, nonatomic) NSString *selectorName;
@property (strong, nonatomic) NSString *currentClassName;
@property (copy, nonatomic) NSString *debugString;

- (instancetype)initWithExpressionKind:(MFExpressionKind)expressionKind;

@end

@interface MFIdentifierExpression: YTXMFExpression

@property (copy, nonatomic) NSString *identifier;

@end


typedef NS_ENUM(NSInteger, MFAssignKind) {
	MF_NORMAL_ASSIGN,
	MF_SUB_ASSIGN,
	MF_ADD_ASSIGN,
	MF_MUL_ASSIGN,
	MF_DIV_ASSIGN,
	MF_MOD_ASSIGN
};


@interface MFAssignExpression: YTXMFExpression

@property (assign, nonatomic) MFAssignKind assignKind;
@property (strong, nonatomic) YTXMFExpression *left;
@property (strong, nonatomic) YTXMFExpression *right;

@end

@interface MFBinaryExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *left;
@property (strong, nonatomic) YTXMFExpression *right;

@end


@interface MFTernaryExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *condition;
@property (strong, nonatomic) YTXMFExpression *trueExpr;
@property (strong, nonatomic) YTXMFExpression *falseExpr;

@end


@interface MFUnaryExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *expr;

@end


@interface MFMemberExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *expr;
@property (copy, nonatomic) NSString *memberName;
@property (assign, nonatomic) BOOL c2methodName;

@end


@interface MFFunctonCallExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *expr;
@property (strong, nonatomic) NSArray<YTXMFExpression *> *args;

@end


@interface MFSubScriptExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *aboveExpr;
@property (strong, nonatomic) YTXMFExpression *bottomExpr;

@end


@interface MFStructEntry:NSObject

@property (copy, nonatomic) NSString *key;
@property (strong, nonatomic) YTXMFExpression *valueExpr;

@end

@interface MFStructpression: YTXMFExpression

@property (strong, nonatomic) NSArray<MFStructEntry *> *entriesExpr;

@end


@interface MFDicEntry: NSObject

@property (strong, nonatomic) YTXMFExpression *keyExpr;
@property (strong, nonatomic) YTXMFExpression *valueExpr;

@end


@interface MFDictionaryExpression: YTXMFExpression

@property (strong, nonatomic) NSArray<MFDicEntry *> *entriesExpr;

@end


@interface MFArrayExpression: YTXMFExpression

@property (strong, nonatomic) NSArray<YTXMFExpression *> *itemExpressions;

@end


@interface MFBlockExpression: YTXMFExpression

@property (strong, nonatomic) YTXMFFunctionDefinition *func;

@end




@interface MFCFuntionExpression : YTXMFExpression

@property (strong, nonatomic) YTXMFExpression *cfunNameOrPointerExpr;

@end






















