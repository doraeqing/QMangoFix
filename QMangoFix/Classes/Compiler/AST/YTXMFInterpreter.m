//
//  MFTranslationUtil.m
//  MangoFix
//
//  Created by jerry.yong on 2017/11/23.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import "YTXMFInterpreter.h"
#import "runenv.h"

static YTXMFScopeChain *st_commonScope;

@implementation YTXMFInterpreter

- (instancetype)init{
	if (self = [super init]) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			st_commonScope = [[YTXMFScopeChain alloc] init];
		});
		_currentLineNumber = 1;
		
		_topScope = [YTXMFScopeChain scopeChainWithNext:st_commonScope];
		_commonScope = st_commonScope;
	}
	return self;
}

- (YTXMFStack *)stack{
    
    YTXMFStack *stack = [NSThread currentThread].threadDictionary[@"mf_stack"];
    if (!stack) {
        stack= [[YTXMFStack alloc] init];
        [NSThread currentThread].threadDictionary[@"mf_stack"] = stack;
    }
    return stack;
}

- (NSMutableDictionary<NSString *,YTXMFClassDefinition *> *)classDefinitionDic{
	if (_classDefinitionDic == nil) {
		_classDefinitionDic = [NSMutableDictionary dictionary];
	}
	return _classDefinitionDic;
}


- (NSMutableDictionary<NSString *,YTXMFStructDeclare *> *)structDeclareDic{
	if (_structDeclareDic == nil) {
		_structDeclareDic = [NSMutableDictionary dictionary];
	}
	return _structDeclareDic;
}



- (NSMutableArray<YTXMFStatement *> *)topList{
	if (_topList == nil) {
		_topList = [NSMutableArray array];
	}
	return _topList;
}


- (void)compileSourceWithString:(NSString *)source{
	extern void mf_set_source_string(char const *source);
	mf_set_source_string([source UTF8String]);
	extern void yyrestart  (FILE * input_file );
	extern int yyparse(void);
    yyrestart(NULL); /* 每次解析前，重置yylex */
	if (yyparse()) {
		return;
	}
	
}

@end
