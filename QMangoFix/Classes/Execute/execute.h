//
//  execute.h
//  MangoFix
//
//  Created by jerry.yong on 2017/12/26.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#ifndef execute_h
#define execute_h
#import "runenv.h"

/*built-in.m*/
void mf_add_built_in(YTXMFInterpreter *inter);


/* eval.m */
BOOL mf_equal_value(NSUInteger lineNumber,YTXMFValue *value1, YTXMFValue *value2);
YTXMFValue *mf_eval_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,YTXMFExpression *expr);
void mf_interpret(YTXMFInterpreter *inter);


/*execute.m*/
YTXMFStatementResult *mf_execute_statement_list(YTXMFInterpreter *inter, YTXMFScopeChain *scope, NSArray<YTXMFStatement *> *statementList);
YTXMFValue * mf_call_mf_function(YTXMFInterpreter *inter, YTXMFScopeChain *scope, YTXMFFunctionDefinition *func, NSArray<YTXMFValue *> *args);

#endif /* execute_h */
