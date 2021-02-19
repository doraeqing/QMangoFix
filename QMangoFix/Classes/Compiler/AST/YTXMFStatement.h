//
//  MFStatement.h
//  MangoFix
//
//  Created by jerry.yong on 2017/11/16.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFExpression.h"
#import "YTXMFDeclaration.h"
@class YTXMFBlockBody;

typedef NS_ENUM(NSInteger, MFStatementKind) {
	MFStatementKindExpression = 1,
	MFStatementKindDeclaration,
	MFStatementKindIf,
	MFStatementKindSwitch,
	MFStatementKindFor,
	MFStatementKindForEach,
	MFStatementKindWhile,
	MFStatementKindDoWhile,
	MFStatementKindBreak,
	MFStatementKindContinue,
	MFStatementKindReturn
};

@interface YTXMFStatement : NSObject

@property (assign, nonatomic) MFStatementKind kind;

@end



@interface MFExpressionStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *expr;

@end




@interface MFDeclarationStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFDeclaration *declaration;

@end


@interface MFElseIf: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *condition;
@property (strong, nonatomic) YTXMFBlockBody *thenBlock;

@end

@interface MFIfStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *condition;
@property (strong, nonatomic) YTXMFBlockBody *thenBlock;
@property (strong, nonatomic) YTXMFBlockBody *elseBlocl;
@property (strong, nonatomic) NSArray<MFElseIf *> *elseIfList;

@end


@interface MFCase: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *expr;
@property (strong, nonatomic) YTXMFBlockBody *block;

@end

@interface MFSwitchStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *expr;
@property (strong, nonatomic) NSArray<MFCase *> *caseList;
@property (strong, nonatomic) YTXMFBlockBody *defaultBlock;

@end

@interface MFForStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *initializerExpr;
@property (strong, nonatomic) YTXMFDeclaration *declaration;
@property (strong, nonatomic) YTXMFExpression *condition;
@property (strong, nonatomic) YTXMFExpression *post;
@property (strong, nonatomic) YTXMFBlockBody *block;

@end

@interface MFForEachStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFDeclaration *declaration;
@property (strong, nonatomic) MFIdentifierExpression *identifierExpr;
@property (strong, nonatomic) YTXMFExpression *collectionExpr;
@property (strong, nonatomic) YTXMFBlockBody *block;

@end

@interface MFWhileStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *condition;
@property (strong, nonatomic) YTXMFBlockBody *block;

@end


@interface MFDoWhileStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFBlockBody *block;
@property (strong, nonatomic) YTXMFExpression *condition;

@end

@interface MFContinueStatement: YTXMFStatement

@end


@interface MFBreakStatement: YTXMFStatement

@end


@interface MFReturnStatement: YTXMFStatement

@property (strong, nonatomic) YTXMFExpression *retValExpr;

@end














