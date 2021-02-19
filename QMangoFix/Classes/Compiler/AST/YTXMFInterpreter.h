//
//  MFTranslationUtil.h
//  MangoFix
//
//  Created by jerry.yong on 2017/11/23.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFClassDefinition.h"
#import "YTXMFStructDeclare.h"
@class YTXMFScopeChain;
@class YTXMFStack;

@interface YTXMFInterpreter : NSObject

@property (assign, nonatomic) int currentLineNumber;
@property (strong, nonatomic) NSMutableDictionary<NSString *, YTXMFStructDeclare *> *structDeclareDic;
@property (strong, nonatomic) NSMutableDictionary<NSString *, YTXMFClassDefinition *> *classDefinitionDic;

@property (strong, nonatomic) NSMutableArray *topList;
@property (strong, nonatomic) YTXMFClassDefinition *currentClassDefinition;
@property (strong, nonatomic) YTXMFBlockBody *currentBlock;

@property (strong, nonatomic) YTXMFScopeChain *topScope;
@property (strong, nonatomic) YTXMFScopeChain *commonScope;

@property (strong, nonatomic) YTXMFStack *stack;

- (void)compileSourceWithString:(NSString *)source;

@end
