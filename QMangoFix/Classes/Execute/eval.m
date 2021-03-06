//
//  eval.m
//  MangoFix
//
//  Created by jerry.yong on 2017/12/25.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <symdl/symdl.h>
#import "mf_ast.h"
#import "ffi.h"
#import "util.h"
#import "mf_ast.h"
#import "execute.h"
#import "create.h"
#import "YTXMFValue+Private.h"
#import "YTXMFVarDeclareChain.h"

static void eval_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, __kindof YTXMFExpression *expr);

static YTXMFValue *invoke_values(id instance, SEL sel, NSArray<YTXMFValue *> *argValues){
    if (!instance) {
        return [YTXMFValue valueInstanceWithInt:0];
    }
    NSMethodSignature *sig = [instance methodSignatureForSelector:sel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
    invocation.target = instance;
    invocation.selector = sel;
    NSUInteger argCount = [sig numberOfArguments];
    for (NSUInteger i = 2; i < argCount; i++) {
        const char *typeEncoding = [sig getArgumentTypeAtIndex:i];
        void *ptr = malloc(mf_size_with_encoding(typeEncoding));
        [argValues[i-2] assignToCValuePointer:ptr typeEncoding:typeEncoding];
        [invocation setArgument:ptr atIndex:i];
        free(ptr);
    }
    [invocation invoke];
    
    char *returnType = (char *)[sig methodReturnType];
    returnType = removeTypeEncodingPrefix(returnType);
    YTXMFValue *retValue;
    if (*returnType != 'v') {
        void *retValuePointer = malloc([sig methodReturnLength]);
        [invocation getReturnValue:retValuePointer];
        NSString *selectorName = NSStringFromSelector(sel);
        if ([selectorName isEqualToString:@"alloc"] || [selectorName isEqualToString:@"new"] ||
            [selectorName isEqualToString:@"copy"] || [selectorName isEqualToString:@"mutableCopy"]) {
            retValue = [[YTXMFValue alloc] initWithCValuePointer:retValuePointer typeEncoding:returnType bridgeTransfer:YES];
        }else{
            retValue = [[YTXMFValue alloc] initWithCValuePointer:retValuePointer typeEncoding:returnType bridgeTransfer:NO];
        }
        
        free(retValuePointer);
    }else{
        retValue = [YTXMFValue voidValueInstance];
    }
    return retValue;
}



static YTXMFValue *invoke(NSUInteger line, YTXMFInterpreter *inter, YTXMFScopeChain *scope, id instance, SEL sel, NSArray<YTXMFExpression *> *argExprs){
    if (!instance) {
        for (YTXMFExpression *argExpr in argExprs) {
            eval_expression(inter, scope, argExpr);
            [inter.stack pop];
        }
        return [YTXMFValue valueInstanceWithInt:0];
    }
    
    NSMutableArray<YTXMFValue *> *values = [NSMutableArray arrayWithCapacity:argExprs.count];
    for (YTXMFExpression *expr in argExprs) {
        eval_expression(inter, scope, expr);
        YTXMFValue *argValue = [inter.stack pop];
        [values addObject:argValue];
    }
    return invoke_values(instance, sel, values);
}


static YTXMFValue *invoke_sueper_values(id instance, Class superClass, SEL sel, NSArray<YTXMFValue *> *argValues){
    struct objc_super *superPtr = &(struct objc_super){instance,superClass};
    NSMethodSignature *sig = [instance methodSignatureForSelector:sel];
    NSUInteger argCount = sig.numberOfArguments;
    
    void **args = alloca(sizeof(void *) * argCount);
    ffi_type **argTypes = alloca(sizeof(ffi_type *) * argCount);
    
    argTypes[0] = &ffi_type_pointer;
    args[0] = &superPtr;
    
    argTypes[1] = &ffi_type_pointer;
    args[1] = &sel;
    
    for (NSUInteger i = 2; i < argCount; i++) {
        YTXMFValue *argValue = argValues[i-2];
        char *argTypeEncoding = (char *)[sig getArgumentTypeAtIndex:i];
        argTypeEncoding = removeTypeEncodingPrefix(argTypeEncoding);
        
        
#define mf_SET_FFI_TYPE_AND_ARG_CASE(_code, _type, _ffi_type_value, _sel)\
case _code:{\
argTypes[i] = &_ffi_type_value;\
_type value = (_type)argValue._sel;\
args[i] = &value;\
break;\
}
        
        switch (*argTypeEncoding) {
                mf_SET_FFI_TYPE_AND_ARG_CASE('c', char, ffi_type_schar, c2integerValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('i', int, ffi_type_sint, c2integerValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('s', short, ffi_type_sshort, c2integerValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('l', long, ffi_type_slong, c2integerValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('q', long long, ffi_type_sint64, c2integerValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('C', unsigned char, ffi_type_uchar, c2uintValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('I', unsigned int, ffi_type_uint, c2uintValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('S', unsigned short, ffi_type_ushort, c2uintValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('L', unsigned long, ffi_type_ulong, c2uintValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('Q', unsigned long long, ffi_type_uint64, c2uintValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('B', BOOL, ffi_type_sint8, c2uintValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('f', float, ffi_type_float, c2doubleValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('d', double, ffi_type_double, c2doubleValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('@', id, ffi_type_pointer, c2objectValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('#', Class, ffi_type_pointer, c2objectValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE(':', SEL, ffi_type_pointer, selValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('*', char *, ffi_type_pointer, c2pointerValue)
                mf_SET_FFI_TYPE_AND_ARG_CASE('^', id, ffi_type_pointer, c2pointerValue)
                
            case '{':{
                argTypes[i] = mf_ffi_type_with_type_encoding(argTypeEncoding);
                if (argValue.type.typeKind == MF_TYPE_STRUCT_LITERAL) {
                    size_t structSize = mf_size_with_encoding(argTypeEncoding);
                    void * structPtr = alloca(structSize);
                    YTXMFStructDeclareTable *table = [YTXMFStructDeclareTable shareInstance];
                    NSString *structName = mf_struct_name_with_encoding(argTypeEncoding);
                    YTXMFStructDeclare *declare = [table getStructDeclareWithName:structName];
                    mf_struct_data_with_dic(structPtr, argValue.objectValue, declare);
                    args[i] = structPtr;
                }else if (argValue.type.typeKind == MF_TYPE_STRUCT){
                    args[i] = argValue.pointerValue;
                }else{
                    NSCAssert(0, @"");
                }
                break;
            }
                
                
            default:
                NSCAssert(0, @"not support type  %s", argTypeEncoding);
                break;
        }
        
    }
    
    char *returnTypeEncoding = (char *)[sig methodReturnType];
    returnTypeEncoding = removeTypeEncodingPrefix(returnTypeEncoding);
    ffi_type *rtype = NULL;
    void *rvalue = NULL;
#define mf_FFI_RETURN_TYPE_CASE(_code, _ffi_type)\
case _code:{\
rtype = &_ffi_type;\
rvalue = alloca(rtype->size);\
break;\
}
    
    switch (*returnTypeEncoding) {
            mf_FFI_RETURN_TYPE_CASE('c', ffi_type_schar)
            mf_FFI_RETURN_TYPE_CASE('i', ffi_type_sint)
            mf_FFI_RETURN_TYPE_CASE('s', ffi_type_sshort)
            mf_FFI_RETURN_TYPE_CASE('l', ffi_type_slong)
            mf_FFI_RETURN_TYPE_CASE('q', ffi_type_sint64)
            mf_FFI_RETURN_TYPE_CASE('C', ffi_type_uchar)
            mf_FFI_RETURN_TYPE_CASE('I', ffi_type_uint)
            mf_FFI_RETURN_TYPE_CASE('S', ffi_type_ushort)
            mf_FFI_RETURN_TYPE_CASE('L', ffi_type_ulong)
            mf_FFI_RETURN_TYPE_CASE('Q', ffi_type_uint64)
            mf_FFI_RETURN_TYPE_CASE('B', ffi_type_sint8)
            mf_FFI_RETURN_TYPE_CASE('f', ffi_type_float)
            mf_FFI_RETURN_TYPE_CASE('d', ffi_type_double)
            mf_FFI_RETURN_TYPE_CASE('@', ffi_type_pointer)
            mf_FFI_RETURN_TYPE_CASE('#', ffi_type_pointer)
            mf_FFI_RETURN_TYPE_CASE(':', ffi_type_pointer)
            mf_FFI_RETURN_TYPE_CASE('^', ffi_type_pointer)
            mf_FFI_RETURN_TYPE_CASE('*', ffi_type_pointer)
            mf_FFI_RETURN_TYPE_CASE('v', ffi_type_void)
        case '{':{
            rtype = mf_ffi_type_with_type_encoding(returnTypeEncoding);
            rvalue = alloca(rtype->size);
        }
            
        default:
            NSCAssert(0, @"not support type  %s", returnTypeEncoding);
            break;
    }
    
    
    ffi_cif cif;
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)argCount, rtype, argTypes);
    ffi_call(&cif, objc_msgSendSuper, rvalue, args);
    YTXMFValue *retValue;
    if (*returnTypeEncoding != 'v') {
        retValue = [[YTXMFValue alloc] initWithCValuePointer:rvalue typeEncoding:returnTypeEncoding bridgeTransfer:NO];
    }else{
        retValue = [YTXMFValue voidValueInstance];
    }
    return retValue;
}

static YTXMFValue *invoke_super(NSUInteger line, YTXMFInterpreter *inter, YTXMFScopeChain *scope, id instance,Class superClass, SEL sel, NSArray<YTXMFExpression *> *argExprs){
    if (!instance) {
        for (YTXMFExpression *argExpr in argExprs) {
            eval_expression(inter, scope, argExpr);
            [inter.stack pop];
        }
        return [YTXMFValue valueInstanceWithInt:0];
    }
    NSMutableArray<YTXMFValue *> *values = [NSMutableArray arrayWithCapacity:argExprs.count];
    for (YTXMFExpression *expr in argExprs) {
        eval_expression(inter, scope, expr);
        YTXMFValue *argValue = [inter.stack pop];
        [values addObject:argValue];
    }
    return invoke_sueper_values(instance,superClass, sel, values);
}







static YTXMFValue *get_struct_field_value(void *structData,YTXMFStructDeclare *declare,NSString *key){
    NSString *typeEncoding = [NSString stringWithUTF8String:declare.typeEncoding];
    NSString *types = [typeEncoding substringToIndex:typeEncoding.length-1];
    NSUInteger location = [types rangeOfString:@"="].location + 1;
    types = [types substringFromIndex:location];
    const char *encoding = types.UTF8String;
    size_t postion = 0;
    NSUInteger index = [declare.keys indexOfObject:key];
    if (index == NSNotFound) {
        NSCAssert(0, @"key %@ not found of struct %@", key, declare.name);
    }
    YTXMFValue *retValue = [[YTXMFValue alloc] init];
    NSUInteger i = 0;
    for (size_t j = 0; j < declare.keys.count; j++) {
#define mf_GET_STRUCT_FIELD_VALUE_CASE(_code,_type,_kind,_sel)\
case _code:{\
if (j == index) {\
_type value = *(_type *)(structData + postion);\
retValue.type = mf_create_type_specifier(_kind);\
retValue._sel = value;\
return retValue;\
}\
postion += sizeof(_type);\
break;\
}
        switch (encoding[i]) {
                mf_GET_STRUCT_FIELD_VALUE_CASE('c',char,MF_TYPE_INT,integerValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('i',int,MF_TYPE_INT,integerValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('s',short,MF_TYPE_INT,integerValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('l',long,MF_TYPE_INT,integerValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('q',long long,MF_TYPE_INT,integerValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('C',unsigned char,MF_TYPE_U_INT,uintValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('I',unsigned int,MF_TYPE_U_INT,uintValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('S',unsigned short,MF_TYPE_U_INT,uintValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('L',unsigned long,MF_TYPE_U_INT,uintValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('Q',unsigned long long,MF_TYPE_U_INT,uintValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('f',float,MF_TYPE_DOUBLE,doubleValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('d',double,MF_TYPE_DOUBLE,doubleValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('B',BOOL,MF_TYPE_U_INT,uintValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('^',void *,MF_TYPE_POINTER,pointerValue);
                mf_GET_STRUCT_FIELD_VALUE_CASE('*',char *,MF_TYPE_C_STRING,cstringValue);
                
                
            case '{':{
                size_t stackSize = 1;
                size_t end = i + 1;
                for (char c = encoding[end]; c ; end++, c = encoding[end]) {
                    if (c == '{') {
                        stackSize++;
                    }else if (c == '}') {
                        stackSize--;
                        if (stackSize == 0) {
                            break;
                        }
                    }
                }
                
                NSString *subTypeEncoding = [types substringWithRange:NSMakeRange(i, end - i + 1)];
                size_t size = mf_size_with_encoding(subTypeEncoding.UTF8String);
                if(j == index){
                    void *value = structData + postion;
                    YTXMFValue *retValue = [YTXMFValue valueInstanceWithStruct:value typeEncoding:subTypeEncoding.UTF8String copyData:NO];
                    return retValue;
                }
                
                
                postion += size;
                i = end;
                break;
            }
            default:
                break;
        }
        i++;
    }
    NSCAssert(0, @"struct %@ typeEncoding error %@", declare.name, typeEncoding);
    return nil;
}


static void set_struct_field_value(void *structData,YTXMFStructDeclare *declare,NSString *key, YTXMFValue *value){
    NSString *typeEncoding = [NSString stringWithUTF8String:declare.typeEncoding];
    NSString *types = [typeEncoding substringToIndex:typeEncoding.length-1];
    NSUInteger location = [types rangeOfString:@"="].location+1;
    types = [types substringFromIndex:location];
    const char *encoding = types.UTF8String;
    size_t postion = 0;
    NSUInteger index = [declare.keys indexOfObject:key];
    if (index == NSNotFound) {
        NSCAssert(0, @"key %@ not found of struct %@", key, declare.name);
    }
    NSUInteger i = 0;
    for (size_t j = 0; j < declare.keys.count; j++) {
#define mf_SET_STRUCT_FIELD_VALUE_CASE(_code,_type,_sel)\
case _code:{\
if (j == index) {\
*(_type *)(structData + postion) = (_type)value._sel;\
return ;\
}\
postion += sizeof(_type);\
break;\
}
        switch (encoding[i]) {
                mf_SET_STRUCT_FIELD_VALUE_CASE('c',char,c2integerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('i',int,c2integerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('s',short,c2integerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('l',long,c2integerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('q',long long,c2integerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('C',unsigned char,c2uintValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('I',unsigned int,c2uintValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('S',unsigned short,c2uintValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('L',unsigned long,c2uintValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('Q',unsigned long long,c2uintValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('f',float,c2doubleValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('d',double,c2doubleValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('B',BOOL,c2integerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('^',void *,c2pointerValue);
                mf_SET_STRUCT_FIELD_VALUE_CASE('*',char *,cstringValue);
                
                
            case '{':{
                size_t stackSize = 1;
                size_t end = i + 1;
                for (char c = encoding[end]; c ; end++, c = encoding[end]) {
                    if (c == '{') {
                        stackSize++;
                    }else if (c == '}') {
                        stackSize--;
                        if (stackSize == 0) {
                            break;
                        }
                    }
                }
                
                NSString *subTypeEncoding = [types substringWithRange:NSMakeRange(i, end - i + 1)];
                size_t size = mf_size_with_encoding(subTypeEncoding.UTF8String);
                if(j == index){
                    void *valuePtr = structData + postion;
                    [value assignToCValuePointer:valuePtr typeEncoding:subTypeEncoding.UTF8String];
                    return;
                }
                postion += size;
                i = end;
                break;
            }
            default:
                break;
        }
        i++;
    }
}




static void eval_bool_exprseeion(YTXMFInterpreter *inter, YTXMFExpression *expr){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_BOOL);
	value.uintValue = expr.boolValue;
	[inter.stack push:value];
}

static void eval_u_interger_expression(YTXMFInterpreter *inter, YTXMFExpression *expr){
    YTXMFValue *value = [YTXMFValue new];
    value.type = mf_create_type_specifier(MF_TYPE_U_INT);
    value.uintValue = expr.uintValue;
    [inter.stack push:value];
}

static void eval_interger_expression(YTXMFInterpreter *inter, YTXMFExpression *expr){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_INT);
	value.integerValue = expr.integerValue;
	[inter.stack push:value];
}

static void eval_double_expression(YTXMFInterpreter *inter, YTXMFExpression *expr){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_DOUBLE);
	value.doubleValue = expr.doubleValue;
	[inter.stack push:value];
}

static void eval_string_expression(YTXMFInterpreter *inter, YTXMFExpression *expr){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_C_STRING);
	value.cstringValue = expr.cstringValue;
	[inter.stack push:value];
}

static void eval_sel_expression(YTXMFInterpreter *inter, YTXMFExpression *expr){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_SEL);
	value.selValue = NSSelectorFromString(expr.selectorName);
	[inter.stack push:value];
}


static void copy_undef_var(id exprOrStatement, YTXMFVarDeclareChain *chain, YTXMFScopeChain *fromScope, YTXMFScopeChain *endScope,YTXMFScopeChain *destScope){
    if (!exprOrStatement) {
        return;
    }
    Class exprOrStatementClass = [exprOrStatement class];
    if (exprOrStatementClass == YTXMFExpression.class) {
        YTXMFExpression *expr = (YTXMFExpression *)exprOrStatement;
        if (expr.expressionKind == MF_SELF_EXPRESSION || expr.expressionKind == MF_SUPER_EXPRESSION) {
            NSString *identifier = @"self";
            if (![chain isInChain:identifier]) {
                YTXMFValue *value = [fromScope getValueWithIdentifier:identifier endScope:endScope];
                if (value) {
                    [destScope setValue:value withIndentifier:identifier];
                }
            }
            return;
        }
    }else if (exprOrStatementClass == MFIdentifierExpression.class) {
        MFIdentifierExpression *expr = (MFIdentifierExpression *)exprOrStatement;
        NSString *identifier = expr.identifier;
        if (![chain isInChain:identifier]) {
           YTXMFValue *value = [fromScope getValueWithIdentifier:identifier endScope:endScope];
            if (value) {
                [destScope setValue:value withIndentifier:identifier];
            }
        }
        return;
        
    }else if (exprOrStatementClass == MFAssignExpression.class) {
        MFAssignExpression *expr = (MFAssignExpression *)exprOrStatement;
        copy_undef_var(expr.left, chain, fromScope, endScope, destScope);
        copy_undef_var(expr.right, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFBinaryExpression.class){
        MFBinaryExpression *expr = (MFBinaryExpression *)exprOrStatement;
        copy_undef_var(expr.left, chain, fromScope, endScope, destScope);
        copy_undef_var(expr.right, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFTernaryExpression.class){
        MFTernaryExpression *expr = (MFTernaryExpression *)exprOrStatement;
        copy_undef_var(expr.condition, chain, fromScope, endScope, destScope);
        copy_undef_var(expr.trueExpr, chain, fromScope, endScope, destScope);
        copy_undef_var(expr.falseExpr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFUnaryExpression.class){
        MFUnaryExpression *expr = (MFUnaryExpression *)exprOrStatement;
        copy_undef_var(expr.expr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFMemberExpression.class){
        MFMemberExpression *expr = (MFMemberExpression *)exprOrStatement;
        copy_undef_var(expr.expr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFFunctonCallExpression.class){
        MFFunctonCallExpression *expr = (MFFunctonCallExpression *)exprOrStatement;
        copy_undef_var(expr.expr, chain, fromScope, endScope, destScope);
        for (YTXMFExpression *argExpr in expr.args) {
            copy_undef_var(argExpr, chain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFSubScriptExpression.class){
        MFSubScriptExpression *expr = (MFSubScriptExpression *)exprOrStatement;
        copy_undef_var(expr.aboveExpr, chain, fromScope, endScope, destScope);
        copy_undef_var(expr.bottomExpr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFStructEntry.class){
        MFStructEntry *expr = (MFStructEntry *)exprOrStatement;
        copy_undef_var(expr.valueExpr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFStructpression.class){
        MFStructpression *expr = (MFStructpression *)exprOrStatement;
        for (YTXMFExpression *entryExpr in expr.entriesExpr) {
            copy_undef_var(entryExpr, chain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFDicEntry.class){
        MFDicEntry *expr = (MFDicEntry *)exprOrStatement;
        copy_undef_var(expr.keyExpr, chain, fromScope, endScope, destScope);
        copy_undef_var(expr.valueExpr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFDictionaryExpression.class){
        MFDictionaryExpression *expr = (MFDictionaryExpression *)exprOrStatement;
        for (YTXMFExpression *entryExpr in expr.entriesExpr) {
            copy_undef_var(entryExpr, chain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFArrayExpression.class){
        MFArrayExpression *expr = (MFArrayExpression *)exprOrStatement;
        for (YTXMFExpression *itemExpression in expr.itemExpressions) {
            copy_undef_var(itemExpression, chain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFBlockExpression.class){
        MFBlockExpression *expr = (MFBlockExpression *)exprOrStatement;
        YTXMFFunctionDefinition *funcDef = expr.func;
        YTXMFVarDeclareChain *funcChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        NSArray *params = funcDef.params;
        for (MFParameter *param in params) {
            NSString *name = param.name;
            [funcChain addIndentifer:name];
        }
        YTXMFBlockBody *funcDefBody = funcDef.block;
        for (YTXMFStatement *statement in funcDefBody.statementList) {
            copy_undef_var(statement, funcChain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFExpressionStatement.class){
        MFExpressionStatement *statement = (MFExpressionStatement *)exprOrStatement;
        copy_undef_var(statement.expr, chain, fromScope, endScope, destScope);
        return;
        
    }else if (exprOrStatementClass == MFDeclarationStatement.class){
        MFDeclarationStatement *statement = (MFDeclarationStatement *)exprOrStatement;
        NSString *name = statement.declaration.name;
        [chain addIndentifer:name];
        
        YTXMFExpression *initializerExpr = statement.declaration.initializer;
        if (initializerExpr) {
            copy_undef_var(initializerExpr, chain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFIfStatement.class){
        MFIfStatement *ifStatement = (MFIfStatement *)exprOrStatement;
        copy_undef_var(ifStatement.condition, chain, fromScope, endScope, destScope);
        
        YTXMFVarDeclareChain *thenChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *statement in ifStatement.thenBlock.statementList) {
            copy_undef_var(statement, thenChain, fromScope, endScope, destScope);
        }
        YTXMFVarDeclareChain *elseChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *statement in ifStatement.elseBlocl.statementList) {
            copy_undef_var(statement, elseChain, fromScope, endScope, destScope);
        }
        
        for (MFElseIf *elseIf in ifStatement.elseIfList) {
            copy_undef_var(elseIf, chain, fromScope, endScope, destScope);
        }
        return;
    }else if (exprOrStatementClass == MFElseIf.class){
        MFElseIf *elseIfStatement = (MFElseIf *)exprOrStatement;
        copy_undef_var(elseIfStatement.condition, chain, fromScope, endScope, destScope);
        YTXMFVarDeclareChain *elseIfChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *statement in elseIfStatement.thenBlock.statementList) {
            copy_undef_var(statement, elseIfChain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFSwitchStatement.class){
        MFSwitchStatement *swithcStatement = (MFSwitchStatement *)exprOrStatement;
        copy_undef_var(swithcStatement.expr, chain, fromScope, endScope, destScope);
        
        for (MFCase *case_ in swithcStatement.caseList) {
            copy_undef_var(case_, chain, fromScope, endScope, destScope);
        }
        
        YTXMFVarDeclareChain *defChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *satement in swithcStatement.defaultBlock.statementList) {
            copy_undef_var(satement, defChain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFCase.class){
        MFCase *caseStatement = (MFCase *)exprOrStatement;
        copy_undef_var(caseStatement.expr, chain, fromScope, endScope, destScope);
        YTXMFVarDeclareChain *caseChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *satement in caseStatement.block.statementList) {
            copy_undef_var(satement, caseChain, fromScope, endScope, destScope);
        }
        return;
        
    }else if (exprOrStatementClass == MFForStatement.class){
        MFForStatement *forStatement = (MFForStatement *)exprOrStatement;
        copy_undef_var(forStatement.initializerExpr, chain, fromScope, endScope, destScope);
        
        YTXMFDeclaration *declaration = forStatement.declaration;
        YTXMFVarDeclareChain *forChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        if (declaration) {
            NSString *name = declaration.name;
            [forChain addIndentifer:name];
        }
        copy_undef_var(forStatement.condition, forChain, fromScope, endScope, destScope);
        
        for (YTXMFStatement *statement in forStatement.block.statementList) {
            copy_undef_var(statement, forChain, fromScope, endScope, destScope);
        }
        
        copy_undef_var(forStatement.post, forChain, fromScope, endScope, destScope);
        
        
    }else if (exprOrStatementClass == MFForEachStatement.class){
        MFForEachStatement *forEachStatement = (MFForEachStatement *)exprOrStatement;
        copy_undef_var(forEachStatement.identifierExpr, chain, fromScope, endScope, destScope);
        
        copy_undef_var(forEachStatement.collectionExpr, chain, fromScope, endScope, destScope);
        
        YTXMFVarDeclareChain *forEachChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        YTXMFDeclaration *declaration = forEachStatement.declaration;
        if (declaration) {
            NSString *name = declaration.name;
            [forEachChain addIndentifer:name];
        }
        for (YTXMFStatement *statement in forEachStatement.block.statementList) {
            copy_undef_var(statement, forEachChain, fromScope, endScope, destScope);
        }
        
        
    }else if (exprOrStatementClass == MFWhileStatement.class){
        MFWhileStatement *whileStatement = (MFWhileStatement *)exprOrStatement;
        copy_undef_var(whileStatement.condition, chain, fromScope, endScope, destScope);
        
        YTXMFVarDeclareChain *whileChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *statement in whileStatement.block.statementList) {
            copy_undef_var(statement, whileChain, fromScope, endScope, destScope);
        }
        
    }else if (exprOrStatementClass == MFDoWhileStatement.class){
        MFWhileStatement *doWhileStatement = (MFWhileStatement *)exprOrStatement;
        copy_undef_var(doWhileStatement.condition, chain, fromScope, endScope, destScope);
        
        YTXMFVarDeclareChain *doWhileChain = [YTXMFVarDeclareChain varDeclareChainWithNext:chain];
        for (YTXMFStatement *statement in doWhileStatement.block.statementList) {
            copy_undef_var(statement, doWhileChain, fromScope, endScope, destScope);
        }
        
    }else if (exprOrStatementClass == MFReturnStatement.class){
        MFReturnStatement *returnStatement = (MFReturnStatement *)exprOrStatement;
        copy_undef_var(returnStatement.retValExpr, chain, fromScope, endScope, destScope);
        return;
    }else if (exprOrStatementClass == MFContinueStatement.class){
        
    }else if (exprOrStatementClass == MFBreakStatement.class){
        
    }
    
}



static void eval_block_expression(YTXMFInterpreter *inter, YTXMFScopeChain *outScope, MFBlockExpression *expr){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_BLOCK);
	YTXMFBlock *manBlock = [[YTXMFBlock alloc] init];
	manBlock.func = expr.func;
	
	YTXMFScopeChain *scope = [YTXMFScopeChain scopeChainWithNext:inter.topScope];
    copy_undef_var(expr, [[YTXMFVarDeclareChain alloc] init], outScope, inter.topScope, scope);
	manBlock.outScope = scope;
	
	manBlock.inter = inter;
	
	NSMutableString *typeEncoding = [NSMutableString stringWithUTF8String:[manBlock.func.returnTypeSpecifier typeEncoding]];
    [typeEncoding appendString:@"@?"];
	for (MFParameter *param in manBlock.func.params) {
		const char *paramTypeEncoding = [param.type typeEncoding];
		[typeEncoding appendString:@(paramTypeEncoding)];
	}
	manBlock.typeEncoding = strdup(typeEncoding.UTF8String);
	__autoreleasing id ocBlock = [manBlock ocBlock];
	value.objectValue = ocBlock;
    CFRelease((__bridge void *)ocBlock);
	[inter.stack push:value];
}


static void eval_nil_expr(YTXMFInterpreter *inter){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_OBJECT);
	value.objectValue = nil;
	[inter.stack push:value];
}


static void eval_null_expr(YTXMFInterpreter *inter){
	YTXMFValue *value = [YTXMFValue new];
	value.type = mf_create_type_specifier(MF_TYPE_POINTER);
	value.pointerValue = NULL;
	[inter.stack push:value];
}


static void eval_identifer_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope ,MFIdentifierExpression *expr){
	NSString *identifier = expr.identifier;
	YTXMFValue *value = [scope getValueWithIdentifierInChain:identifier];
	if (!value) {
		Class clazz = NSClassFromString(identifier);
		if (clazz) {
			value = [YTXMFValue valueInstanceWithClass:clazz];
		}
	}
	NSCAssert(value, @"not found var %@", identifier);
	[inter.stack push:value];
}


static void eval_ternary_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFTernaryExpression *expr){
	eval_expression(inter, scope, expr.condition);
	YTXMFValue *conValue = [inter.stack pop];
	if (conValue.isSubtantial) {
		if (expr.trueExpr) {
			eval_expression(inter, scope, expr.trueExpr);
		}else{
			[inter.stack push:conValue];
		}
	}else{
		eval_expression(inter, scope, expr.falseExpr);
	}
	
}


static void eval_function_call_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFFunctonCallExpression *expr);
static YTXMFValue *invoke_values(id instance, SEL sel, NSArray<YTXMFValue *> *values);


static void eval_assign_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFAssignExpression *expr){
	MFAssignKind assignKind = expr.assignKind;
	YTXMFExpression *leftExpr = expr.left;
	YTXMFExpression *rightExpr = expr.right;
	
	switch (leftExpr.expressionKind) {
        case MF_IDENTIFIER_EXPRESSION:
		case MF_MEMBER_EXPRESSION:{
			YTXMFExpression *optrExpr;
			if (assignKind == MF_NORMAL_ASSIGN) {
				optrExpr = rightExpr;
			}else{
                MFBinaryExpression *binExpr = [[MFBinaryExpression alloc] init];
                binExpr.left = leftExpr;
                binExpr.right = rightExpr;
                optrExpr = binExpr;
				switch (assignKind) {
					case MF_ADD_ASSIGN:{
						binExpr.expressionKind = MF_ADD_EXPRESSION;
						break;
					}
					case MF_SUB_ASSIGN:{
						binExpr.expressionKind = MF_SUB_EXPRESSION;
						break;
					}
					case MF_MUL_ASSIGN:{
						binExpr.expressionKind = MF_MUL_EXPRESSION;
						break;
					}
					case MF_DIV_ASSIGN:{
						binExpr.expressionKind = MF_DIV_EXPRESSION;
						break;
					}
					case MF_MOD_ASSIGN:{
						binExpr.expressionKind = MF_MOD_EXPRESSION;
						break;
					}
					default:
						break;
				}
				
            }
            
            eval_expression(inter, scope, optrExpr);
            YTXMFValue *operValue = [inter.stack pop];
            if (leftExpr.expressionKind == MF_IDENTIFIER_EXPRESSION) {
                MFIdentifierExpression *identiferExpr = (MFIdentifierExpression *)leftExpr;
                [scope assignWithIdentifer:identiferExpr.identifier value:operValue];
            }else{
                MFMemberExpression *memberExpr = (MFMemberExpression *)leftExpr;
                eval_expression(inter, scope, memberExpr.expr);
                YTXMFValue *memberObjValue = [inter.stack pop];
                if (memberObjValue.type.typeKind == MF_TYPE_STRUCT) {
                    YTXMFStructDeclareTable *table = [YTXMFStructDeclareTable shareInstance];
                    set_struct_field_value(memberObjValue.pointerValue, [table getStructDeclareWithName:memberObjValue.type.structName],  memberExpr.memberName, operValue);
                }else{
                    if (memberObjValue.type.typeKind != MF_TYPE_OBJECT && memberObjValue.type.typeKind != MF_TYPE_CLASS) {
                        NSCAssert(0, @"line:%zd, %@ is not object",memberExpr.expr.lineNumber, memberObjValue.type.typeName);
                    }
                    //调用对象setter方法
                    NSString *memberName = memberExpr.memberName;
                    NSString *first = [[memberName substringToIndex:1] uppercaseString];
                    NSString *other = memberName.length > 1 ? [memberName substringFromIndex:1] : nil;
                    memberName = [NSString stringWithFormat:@"set%@%@:",first,other];
                    if (memberExpr.expr.expressionKind == MF_SUPER_EXPRESSION) {
                        Class currentClass = objc_getClass(memberExpr.expr.currentClassName.UTF8String);
                        Class superClass = class_getSuperclass(currentClass);
                        invoke_sueper_values([memberObjValue c2objectValue], superClass, NSSelectorFromString(memberName), @[operValue]);
                    }else{
                        invoke_values([memberObjValue c2objectValue], NSSelectorFromString(memberName), @[operValue]);
                    }
                }
            }
            [inter.stack push:operValue];
			break;
		}
		case MF_SELF_EXPRESSION:{
			NSCAssert(assignKind == MF_NORMAL_ASSIGN, @"");
			eval_expression(inter, scope, rightExpr);
			YTXMFValue *rightValue = [inter.stack pop];
			[scope assignWithIdentifer:@"self" value:rightValue];
            [inter.stack push:rightValue];
			break;
		}
			
		case MF_SUB_SCRIPT_EXPRESSION:{
			MFSubScriptExpression *subScriptExpr = (MFSubScriptExpression *)leftExpr;
			eval_expression(inter, scope, rightExpr);
			YTXMFValue *rightValue = [inter.stack pop];
			eval_expression(inter, scope, subScriptExpr.aboveExpr);
			YTXMFValue *aboveValue =  [inter.stack pop];
			eval_expression(inter, scope, subScriptExpr.bottomExpr);
			YTXMFValue *bottomValue = [inter.stack pop];
			switch (bottomValue.type.typeKind) {
				case MF_TYPE_BOOL:
				case MF_TYPE_INT:
				case MF_TYPE_U_INT:
					aboveValue.objectValue[bottomValue.c2integerValue] = rightValue.objectValue;
					break;
				case MF_TYPE_CLASS:
					aboveValue.objectValue[(id<NSCopying>)bottomValue.classValue] = rightValue.objectValue;
					break;
				case MF_TYPE_OBJECT:
				case MF_TYPE_BLOCK:
					aboveValue.objectValue[bottomValue.objectValue] = rightValue.objectValue;
					break;
				default:
					NSCAssert(0, @"");
					break;
			}
            [inter.stack push:rightValue];
			break;
		}
		default:
			NSCAssert(0, @"");
			break;
	}

}


#define arithmeticalOperation(operation,operationName) \
if (leftValue.type.typeKind == MF_TYPE_DOUBLE || rightValue.type.typeKind == MF_TYPE_DOUBLE) {\
resultValue.type = mf_create_type_specifier(MF_TYPE_DOUBLE);\
if (leftValue.type.typeKind == MF_TYPE_DOUBLE) {\
switch (rightValue.type.typeKind) {\
case MF_TYPE_DOUBLE:\
resultValue.doubleValue = leftValue.doubleValue operation rightValue.doubleValue;\
break;\
case MF_TYPE_INT:\
resultValue.doubleValue = leftValue.doubleValue operation rightValue.integerValue;\
break;\
case MF_TYPE_U_INT:\
resultValue.doubleValue = leftValue.doubleValue operation rightValue.uintValue;\
break;\
default:\
NSCAssert(0, @"line:%zd, " #operationName  " operation not support type: %@",expr.right.lineNumber ,rightValue.type.typeName);\
break;\
}\
}else{\
switch (leftValue.type.typeKind) {\
case MF_TYPE_INT:\
resultValue.doubleValue = leftValue.integerValue operation rightValue.doubleValue;\
break;\
case MF_TYPE_U_INT:\
resultValue.doubleValue = leftValue.uintValue operation rightValue.doubleValue;\
break;\
default:\
NSCAssert(0, @"line:%zd, " #operationName  " operation not support type: %@",expr.left.lineNumber ,leftValue.type.typeName);\
break;\
}\
}\
}else if (leftValue.type.typeKind == MF_TYPE_INT || rightValue.type.typeKind == MF_TYPE_INT){\
resultValue.type = mf_create_type_specifier(MF_TYPE_INT);\
if (leftValue.type.typeKind == MF_TYPE_INT) {\
switch (rightValue.type.typeKind) {\
case MF_TYPE_INT:\
resultValue.integerValue = leftValue.integerValue operation rightValue.integerValue;\
break;\
case MF_TYPE_U_INT:\
resultValue.integerValue = leftValue.integerValue operation rightValue.uintValue;\
break;\
default:\
NSCAssert(0, @"line:%zd, " #operationName  " operation not support type: %@",expr.right.lineNumber ,rightValue.type.typeName);\
break;\
}\
}else{\
switch (leftValue.type.typeKind) {\
case MF_TYPE_U_INT:\
resultValue.integerValue = leftValue.uintValue operation rightValue.integerValue;\
break;\
default:\
NSCAssert(0, @"line:%zd, " #operationName  " operation not support type: %@",expr.left.lineNumber ,leftValue.type.typeName);\
break;\
}\
}\
}else if (leftValue.type.typeKind == MF_TYPE_U_INT && rightValue.type.typeKind == MF_TYPE_U_INT){\
resultValue.type = mf_create_type_specifier(MF_TYPE_U_INT);\
resultValue.uintValue = leftValue.uintValue operation rightValue.uintValue;\
}else{\
NSCAssert(0, @"line:%zd, " #operationName  " operation not support type: %@",expr.right.lineNumber ,rightValue.type.typeName);\
}


static void eval_add_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFBinaryExpression  *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	
	if (![leftValue isMember] || ![rightValue isMember]){
		resultValue.type = mf_create_type_specifier(MF_TYPE_OBJECT);
		NSString *str = [NSString stringWithFormat:@"%@%@",[leftValue nsStringValue].objectValue,[rightValue nsStringValue].objectValue];
		resultValue.objectValue = str;
	}else arithmeticalOperation(+,add);
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}


static void eval_sub_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFBinaryExpression  *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	arithmeticalOperation(-,sub);
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}


static void eval_mul_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFBinaryExpression  *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	arithmeticalOperation(*,mul);
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}


static void eval_div_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFBinaryExpression  *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	switch (rightValue.type.typeKind) {
		case MF_TYPE_DOUBLE:
			if (rightValue.doubleValue == 0) {
				NSCAssert(0, @"line:%zd,divisor cannot be zero!",expr.right.lineNumber);
			}
			break;
		case MF_TYPE_INT:
			if (rightValue.integerValue == 0) {
				NSCAssert(0, @"line:%zd,divisor cannot be zero!",expr.right.lineNumber);
			}
			break;
		case MF_TYPE_U_INT:
			if (rightValue.uintValue == 0) {
				NSCAssert(0, @"line:%zd,divisor cannot be zero!",expr.right.lineNumber);
			}
			break;
			
		default:
			NSCAssert(0, @"line:%zd, div operation not support type: %@",expr.right.lineNumber ,rightValue.type.typeName);
			break;
	}
	YTXMFValue *resultValue = [YTXMFValue new];\
	arithmeticalOperation(/,div);
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}



static void eval_mod_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFBinaryExpression  *expr){
	eval_expression(inter, scope, expr.left);
	YTXMFValue *leftValue = [inter.stack peekStack:0];
	if (leftValue.type.typeKind != MF_TYPE_INT && leftValue.type.typeKind != MF_TYPE_U_INT) {
		NSCAssert(0, @"line:%zd, mod operation not support type: %@",expr.left.lineNumber ,leftValue.type.typeName);
	}
	eval_expression(inter, scope, expr.right);
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	if (rightValue.type.typeKind != MF_TYPE_INT && rightValue.type.typeKind != MF_TYPE_U_INT) {
		NSCAssert(0, @"line:%zd, mod operation not support type: %@",expr.right.lineNumber ,rightValue.type.typeName);
	}
	switch (rightValue.type.typeKind) {
		case MF_TYPE_INT:
			if (rightValue.integerValue == 0) {
				NSCAssert(0, @"line:%zd,mod cannot be zero!",expr.right.lineNumber);
			}
			break;
		case MF_TYPE_U_INT:
			if (rightValue.uintValue == 0) {
				NSCAssert(0, @"line:%zd,mod cannot be zero!",expr.right.lineNumber);
			}
			break;
			
		default:
			NSCAssert(0, @"line:%zd, mod operation not support type: %@",expr.right.lineNumber ,rightValue.type.typeName);
			break;
	}
	YTXMFValue *resultValue = [YTXMFValue new];
	if (leftValue.type.typeKind == MF_TYPE_INT || leftValue.type.typeKind == MF_TYPE_INT) {
		resultValue.type = mf_create_type_specifier(MF_TYPE_INT);
		if (leftValue.type.typeKind == MF_TYPE_INT) {
			if (rightValue.type.typeKind == MF_TYPE_INT) {
				resultValue.integerValue = leftValue.integerValue % rightValue.integerValue;
			}else{
				resultValue.integerValue = leftValue.integerValue % rightValue.uintValue;
			}
		}else{
			resultValue.integerValue = leftValue.uintValue % rightValue.integerValue;
		}
	}else{
		resultValue.type = mf_create_type_specifier(MF_TYPE_U_INT);
		resultValue.uintValue = leftValue.uintValue % rightValue.uintValue;
	}
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}
#define number_value_compare(sel,oper)\
switch (value2.type.typeKind) {\
case MF_TYPE_BOOL:\
return value1.sel oper value2.uintValue;\
case MF_TYPE_U_INT:\
return value1.sel oper value2.uintValue;\
case MF_TYPE_INT:\
return value1.sel oper value2.integerValue;\
case MF_TYPE_DOUBLE:\
return value1.sel oper value2.doubleValue;\
default:\
NSCAssert(0, @"line:%zd == 、 != 、 < 、 <= 、 > 、 >= can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);\
break;\
}
BOOL mf_equal_value(NSUInteger lineNumber,YTXMFValue *value1, YTXMFValue *value2){

	
#define object_value_equal(sel)\
switch (value2.type.typeKind) {\
case MF_TYPE_CLASS:\
	return value1.sel == value2.classValue;\
case MF_TYPE_OBJECT:\
case MF_TYPE_BLOCK:\
	return value1.sel == value2.objectValue;\
case MF_TYPE_POINTER:\
	return value1.sel == value2.pointerValue;\
default:\
	NSCAssert(0, @"line:%zd == and != can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);\
	break;\
}\

	switch (value1.type.typeKind) {
		case MF_TYPE_BOOL:
		case MF_TYPE_U_INT:{
			number_value_compare(uintValue, ==);
		}
		case MF_TYPE_INT:{
			number_value_compare(integerValue, ==);
		}
		case MF_TYPE_DOUBLE:{
			number_value_compare(doubleValue, ==);
		}
		case MF_TYPE_C_STRING:{
			switch (value2.type.typeKind) {
				case MF_TYPE_C_STRING:
					 return value1.cstringValue == value2.cstringValue;
					break;
				case MF_TYPE_POINTER:
					return value1.cstringValue == value2.pointerValue;
					break;
				default:
					NSCAssert(0, @"line:%zd == and != can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);
					break;
			}
		}
		case MF_TYPE_SEL:{
			if (value2.type.typeKind == MF_TYPE_SEL) {
				return value1.selValue == value2.selValue;
			} else {
				NSCAssert(0, @"line:%zd == and != can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);
			}
		}
		case MF_TYPE_CLASS:{
			object_value_equal(classValue);
		}
		case MF_TYPE_OBJECT:
		case MF_TYPE_BLOCK:{
			object_value_equal(objectValue);
		}
		case MF_TYPE_POINTER:{
			switch (value2.type.typeKind) {
				case MF_TYPE_CLASS:
					return value2.classValue == value1.pointerValue;
				case MF_TYPE_OBJECT:
					return value2.objectValue == value1.pointerValue;
				case MF_TYPE_BLOCK:
					return value2.objectValue == value1.pointerValue;
				case MF_TYPE_POINTER:
					return value2.pointerValue == value1.pointerValue;
				default:
					NSCAssert(0, @"line:%zd == and != can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);
					break;
			}
		}
		case MF_TYPE_STRUCT:{
			if (value2.type.typeKind == MF_TYPE_STRUCT) {
				if ([value1.type.structName isEqualToString:value2.type.structName]) {
					const char *typeEncoding  = [value1.type typeEncoding];
					size_t size = mf_size_with_encoding(typeEncoding);
					return memcmp(value1.pointerValue, value2.pointerValue, size) == 0;
				}else{
					return NO;
				}
			}else{
				NSCAssert(0, @"line:%zd == and != can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);
				break;
			}
		}
		case MF_TYPE_STRUCT_LITERAL:{
			return NO;
		}
			
		default:NSCAssert(0, @"line:%zd == and != can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);
			break;
	}
#undef object_value_equal
	return NO;
}

static void eval_eq_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	BOOL equal =  mf_equal_value(expr.left.lineNumber, leftValue, rightValue);
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = equal;
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}

static void eval_ne_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	BOOL equal =  mf_equal_value(expr.left.lineNumber, leftValue, rightValue);
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = !equal;
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}



#define compare_number_func(prefix, oper)\
static BOOL prefix##_value(NSUInteger lineNumber,YTXMFValue  *value1, YTXMFValue  *value2){\
switch (value1.type.typeKind) {\
	case MF_TYPE_BOOL:\
	case MF_TYPE_U_INT:\
		number_value_compare(uintValue, oper);\
	case MF_TYPE_INT:\
		number_value_compare(integerValue, oper);\
	case MF_TYPE_DOUBLE:\
		number_value_compare(doubleValue, oper);\
	default:\
		NSCAssert(0, @"line:%zd == 、 != 、 < 、 <= 、 > 、 >= can not use between %@ and %@",lineNumber, value1.type.typeName, value2.type.typeName);\
		break;\
}\
return NO;\
}

compare_number_func(lt, <)
compare_number_func(le, <=)
compare_number_func(ge, >=)
compare_number_func(gt, >)

static void eval_lt_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	BOOL lt = lt_value(expr.left.lineNumber, leftValue, rightValue);
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = lt;
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}


static void eval_le_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	BOOL le = le_value(expr.left.lineNumber, leftValue, rightValue);
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = le;
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}

static void eval_ge_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	BOOL ge = ge_value(expr.left.lineNumber, leftValue, rightValue);
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = ge;
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}


static void eval_gt_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	eval_expression(inter, scope, expr.right);
	YTXMFValue *leftValue = [inter.stack peekStack:1];
	YTXMFValue *rightValue = [inter.stack peekStack:0];
	BOOL gt = gt_value(expr.left.lineNumber, leftValue, rightValue);
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = gt;
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}

static void eval_logic_and_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	YTXMFValue *leftValue = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	if (!leftValue.isSubtantial) {
		resultValue.uintValue = NO;
		[inter.stack pop];
	}else{
		eval_expression(inter, scope, expr.right);
		YTXMFValue *rightValue = [inter.stack peekStack:0];
		if (!rightValue.isSubtantial) {
			resultValue.uintValue = NO;
		}else{
			resultValue.uintValue = YES;
		}
		[inter.stack pop];
	}
	[inter.stack push:resultValue];
}

static void eval_logic_or_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFBinaryExpression *expr){
	eval_expression(inter, scope, expr.left);
	YTXMFValue *leftValue = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	if (leftValue.isSubtantial) {
		resultValue.uintValue = YES;
		[inter.stack pop];
	}else{
		eval_expression(inter, scope, expr.right);
		YTXMFValue *rightValue = [inter.stack peekStack:0];
		if (rightValue.isSubtantial) {
			resultValue.uintValue = YES;
		}else{
			resultValue.uintValue = NO;
		}
		[inter.stack pop];
	}
	[inter.stack push:resultValue];
}

static void eval_logic_not_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFUnaryExpression *expr){
	eval_expression(inter, scope, expr.expr);
	YTXMFValue *value = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_BOOL);
	resultValue.uintValue = !value.isSubtantial;
	[inter.stack pop];
	[inter.stack push:resultValue];
}

static void eval_increment_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFUnaryExpression *expr){
	YTXMFExpression *oneValueExpr = mf_create_expression(MF_INT_EXPRESSION);
	oneValueExpr.integerValue = 1;
	MFBinaryExpression *addExpr = [[MFBinaryExpression alloc] initWithExpressionKind:MF_ADD_EXPRESSION];
	addExpr.left = expr.expr;
	addExpr.right = oneValueExpr;
	MFAssignExpression *assignExpression = (MFAssignExpression *)mf_create_expression(MF_ASSIGN_EXPRESSION);
	assignExpression.assignKind = MF_NORMAL_ASSIGN;
	assignExpression.left = expr.expr;
	assignExpression.right = addExpr;
	eval_expression(inter, scope, assignExpression);
}

static void eval_decrement_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFUnaryExpression *expr){
	
	YTXMFExpression *oneValueExpr = mf_create_expression(MF_INT_EXPRESSION);
	oneValueExpr.integerValue = 1;
	MFBinaryExpression *addExpr = [[MFBinaryExpression alloc] initWithExpressionKind:MF_SUB_EXPRESSION];
	addExpr.left = expr.expr;
	addExpr.right = oneValueExpr;
	MFAssignExpression *assignExpression = (MFAssignExpression *)mf_create_expression(MF_ASSIGN_EXPRESSION);
	assignExpression.assignKind = MF_NORMAL_ASSIGN;
	assignExpression.left = expr.expr;
	assignExpression.right = addExpr;
	eval_expression(inter, scope, assignExpression);
	
	
}
static void eval_negative_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFUnaryExpression *expr){
	eval_expression(inter, scope, expr.expr);
	YTXMFValue *value = [inter.stack pop];
	YTXMFValue *resultValue = [YTXMFValue new];
	switch (value.type.typeKind) {
		case MF_TYPE_INT:
			resultValue.type = mf_create_type_specifier(MF_TYPE_INT);
			resultValue.integerValue = -value.integerValue;
			break;
		case MF_TYPE_BOOL:
		case MF_TYPE_U_INT:
			resultValue.type = mf_create_type_specifier(MF_TYPE_U_INT);
			resultValue.integerValue = - value.uintValue;
			break;
		case MF_TYPE_DOUBLE:
			resultValue.type = mf_create_type_specifier(MF_TYPE_DOUBLE);
			resultValue.doubleValue = - value.doubleValue;
			break;
			
		default:
			NSCAssert(0, @"line:%zd operator ‘-’ can not use type: %@",expr.expr.lineNumber, value.type.typeName);
			break;
	}
    [inter.stack push:resultValue];
    
}


static void eval_sub_script_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFSubScriptExpression *expr){
	eval_expression(inter, scope, expr.bottomExpr);
	YTXMFValue *bottomValue = [inter.stack peekStack:0];
	MFTypeSpecifierKind kind = bottomValue.type.typeKind;
	
	eval_expression(inter, scope, expr.aboveExpr);
	YTXMFValue *arrValue = [inter.stack peekStack:0];
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_OBJECT);
	switch (kind) {
		case MF_TYPE_BOOL:
		case MF_TYPE_U_INT:
		case MF_TYPE_INT:
			resultValue.objectValue = arrValue.objectValue[bottomValue.c2integerValue];
			break;
		case MF_TYPE_BLOCK:
		case MF_TYPE_OBJECT:
			resultValue.objectValue = arrValue.objectValue[bottomValue.objectValue];
			break;
		case MF_TYPE_CLASS:
			resultValue.objectValue = arrValue.objectValue[bottomValue.classValue];
			break;
		default:
			NSCAssert(0, @"line:%zd, index operator can not use type: %@",expr.bottomExpr.lineNumber, bottomValue.type.typeName);
			break;
	}
	[inter.stack pop];
	[inter.stack pop];
	[inter.stack push:resultValue];
}

static void eval_at_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFUnaryExpression *expr){
	eval_expression(inter, scope, expr.expr);
	YTXMFValue *value = [inter.stack pop];
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_OBJECT);
	switch (value.type.typeKind) {
		case MF_TYPE_BOOL:
		case MF_TYPE_U_INT:
			resultValue.objectValue = @(value.uintValue);
			break;
		case MF_TYPE_INT:
			resultValue.objectValue = @(value.integerValue);
			break;
		case MF_TYPE_DOUBLE:
			resultValue.objectValue = @(value.doubleValue);
			break;
		case MF_TYPE_C_STRING:
			resultValue.objectValue = @(value.cstringValue);
			break;
			
		default:
			NSCAssert(0, @"line:%zd operator ‘@’ can not use type: %@",expr.expr.lineNumber, value.type.typeName);
			break;
	}
	[inter.stack push:resultValue];
}

static void eval_get_address_expresion(YTXMFInterpreter *inter, YTXMFScopeChain *scope,MFUnaryExpression *expr){
    eval_expression(inter, scope, expr.expr);
    YTXMFValue *value = [inter.stack pop];
    YTXMFValue *resultValue = [YTXMFValue new];
    resultValue.type = mf_create_type_specifier(MF_TYPE_POINTER);
    resultValue.pointerValue = [value valuePointer];
    [inter.stack push:resultValue];
}


static void eval_struct_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFStructpression *expr){
	NSMutableDictionary *structDic = [NSMutableDictionary dictionary];
	NSArray *entriesExpr =  expr.entriesExpr;
	for (MFStructEntry *entryExpr in entriesExpr) {
		NSString *key = entryExpr.key;
		YTXMFExpression *itemExpr =  entryExpr.valueExpr;
		eval_expression(inter, scope, itemExpr);
		YTXMFValue *value = [inter.stack peekStack:0];
		if (value.isObject) {
			NSCAssert(0, @"line:%zd, struct can not support object type %@", itemExpr.lineNumber, value.type.typeName );
		}
		switch (value.type.typeKind) {
			case MF_TYPE_BOOL:
			case MF_TYPE_U_INT:
				structDic[key] = @(value.uintValue);
				break;
			case MF_TYPE_INT:
				structDic[key] = @(value.integerValue);
				break;
			case MF_TYPE_DOUBLE:
				structDic[key] = @(value.doubleValue);
				break;
			case MF_TYPE_C_STRING:
				structDic[key] = [NSValue valueWithPointer:value.cstringValue];
				break;
			case MF_TYPE_SEL:
				structDic[key] = [NSValue valueWithPointer:value.selValue];
				break;
			case MF_TYPE_STRUCT:
				structDic[key] = value;
				break;
			case MF_TYPE_STRUCT_LITERAL:
				structDic[key] = value.objectValue;
				break;
			case MF_TYPE_POINTER:
				structDic[key] = [NSValue valueWithPointer:value.pointerValue];
				break;
				
			default:
				NSCAssert(0, @"");
				break;
		}
		
		[inter.stack pop];
	}

	YTXMFValue *result = [[YTXMFValue alloc] init];
	result.type = mf_create_type_specifier(MF_TYPE_STRUCT_LITERAL);
	result.objectValue = [structDic copy];
	[inter.stack push:result];
}




static void eval_dic_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFDictionaryExpression *expr){
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];
	for (MFDicEntry *entry in expr.entriesExpr) {
		eval_expression(inter, scope, entry.keyExpr);
		YTXMFValue *keyValue = [inter.stack peekStack:0];
		if (!keyValue.isObject) {
			NSCAssert(0, @"line:%zd key can not bee type:%@",entry.keyExpr.lineNumber, keyValue.type.typeName);
		}
		
		eval_expression(inter, scope, entry.valueExpr);
		YTXMFValue *valueValue = [inter.stack peekStack:0];
		if (!valueValue.isObject) {
			NSCAssert(0, @"line:%zd value can not bee type:%@",entry.keyExpr.lineNumber, valueValue.type.typeName);
		}

		dic[keyValue.c2objectValue] = valueValue.c2objectValue;
		
		[inter.stack pop];
		[inter.stack pop];
	}
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_OBJECT);
	resultValue.objectValue = dic.copy;
	[inter.stack push:resultValue];
}


static void eval_array_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFArrayExpression *expr){
	NSMutableArray *array = [NSMutableArray array];
	for (YTXMFExpression *elementExpr in expr.itemExpressions) {
		eval_expression(inter, scope, elementExpr);
		YTXMFValue *elementValue = [inter.stack peekStack:0];
		if (elementValue.isObject) {
			[array addObject:elementValue.c2objectValue];
		}else{
			NSCAssert(0, @"line:%zd array element type  can not bee type:%@",elementExpr.lineNumber, elementValue.type.typeName);
		}
		
		[inter.stack pop];
	}
	YTXMFValue *resultValue = [YTXMFValue new];
	resultValue.type = mf_create_type_specifier(MF_TYPE_OBJECT);
	resultValue.objectValue = array.copy;
	[inter.stack push:resultValue];
}


static void eval_self_super_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope){
	YTXMFValue *value = [scope getValueWithIdentifierInChain:@"self"];
	NSCAssert(value, @"not found var %@", @"self");
	[inter.stack push:value];
}


static void eval_member_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFMemberExpression *expr){
    if (expr.expr.expressionKind == MF_SUPER_EXPRESSION) {
        MFFunctonCallExpression *funcExpr = [[MFFunctonCallExpression alloc] init];
        funcExpr.expr = expr;
        eval_function_call_expression(inter, scope, funcExpr);
        return;
    }
    
	eval_expression(inter, scope, expr.expr);
	__autoreleasing YTXMFValue *obj = [inter.stack pop];
    YTXMFValue *resultValue;
	if (obj.type.typeKind == MF_TYPE_STRUCT) {
		YTXMFStructDeclareTable *table = [YTXMFStructDeclareTable shareInstance];
		resultValue =  get_struct_field_value(obj.pointerValue, [table getStructDeclareWithName:obj.type.structName], expr.memberName);
    }else{
        if (obj.type.typeKind != MF_TYPE_OBJECT && obj.type.typeKind != MF_TYPE_CLASS) {
            NSCAssert(0, @"line:%zd, %@ is not object",expr.expr.lineNumber, obj.type.typeName);
        }
        SEL sel = NSSelectorFromString(expr.memberName);
        resultValue  = invoke_values(obj.c2objectValue, sel, nil);
    }
	[inter.stack push:resultValue];
}

static YTXMFValue * call_c_function(NSUInteger lineNumber, YTXMFValue *callee, NSArray<YTXMFValue *> *argValues);

static void eval_function_call_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFFunctonCallExpression *expr){
	MFExpressionKind exprKind = expr.expr.expressionKind;
	switch (exprKind) {
		case MF_MEMBER_EXPRESSION:{
			MFMemberExpression *memberExpr = (MFMemberExpression *)expr.expr;
			YTXMFExpression *memberObjExpr = memberExpr.expr;
			SEL sel = NSSelectorFromString(memberExpr.memberName);
			switch (memberObjExpr.expressionKind) {
				case MF_SELF_EXPRESSION:{
					id _self = [[scope getValueWithIdentifierInChain:@"self"] objectValue];
					YTXMFValue *retValue = invoke(expr.lineNumber, inter, scope,_self, sel, expr.args);
					[inter.stack push:retValue];
					break;
				}
				case MF_SUPER_EXPRESSION:{
					id _self = [[scope getValueWithIdentifierInChain:@"self"] objectValue];
                    Class currentClass = objc_getClass(memberObjExpr.currentClassName.UTF8String);
					Class superClass = class_getSuperclass(currentClass);
                    YTXMFValue *retValue = invoke_super(memberObjExpr.lineNumber, inter, scope, _self, superClass, sel, expr.args);
                    [inter.stack push:retValue];
					break;
				}
				default:{
					eval_expression(inter, scope, memberObjExpr);
					YTXMFValue *memberObj = [inter.stack pop];
					YTXMFValue *retValue = invoke(expr.lineNumber, inter, scope, [memberObj c2objectValue], sel, expr.args);
					[inter.stack push:retValue];
					break;
				}
			}
			
			
			break;
		}
		case MF_IDENTIFIER_EXPRESSION:
		case MF_FUNCTION_CALL_EXPRESSION:{
			eval_expression(inter, scope, expr.expr);
			YTXMFValue *callee = [inter.stack pop];
            
            static Class blockClass = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                blockClass = [^{} class];
                while (blockClass) {
                    Class superClass = class_getSuperclass(blockClass);
                    if (superClass == nil) {
                        break;
                    }
                    blockClass = superClass;
                }
            });
            
            if (callee.type.typeKind != MF_TYPE_C_FUNCTION && !(callee.isObject && [callee.objectValue isKindOfClass:blockClass])) {
                mf_throw_error(expr.expr.lineNumber, MFRuntimeErrorCallCanNotBeCalleeValue, @"type: %@ value can not be callee",callee.type.typeName);
                return;
            }
            
            if (callee.type.typeKind == MF_TYPE_C_FUNCTION) {
                if (callee.pointerValue == NULL) {
                    mf_throw_error(expr.expr.lineNumber, MFRuntimeErrorNullPointer, nil);
                    return;
                }
                
                NSUInteger paramListCount =  callee.type.paramListTypeEncode.count;
                if (paramListCount != expr.args.count) {
                    mf_throw_error(expr.lineNumber, MFRuntimeErrorParameterListCountNoMatch, @"expect count: %zd, pass in cout:%zd",paramListCount, expr.args.count);
                    return;
                }
                
                NSMutableArray *paramValues = [NSMutableArray arrayWithCapacity:paramListCount];
                for (YTXMFExpression *argExpr in expr.args) {
                    eval_expression(inter, scope, argExpr);
                    YTXMFValue *value = [inter.stack pop];
                    [paramValues addObject:value];
                }
                YTXMFValue *retValue = call_c_function(expr.lineNumber,callee, paramValues.copy);
                [inter.stack push:retValue];
            }else{
                const char *blockTypeEncoding = [YTXMFBlock typeEncodingForBlock:callee.c2objectValue];
                NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:blockTypeEncoding];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
                [invocation setTarget:callee.objectValue];
                
                NSUInteger numberOfArguments = [sig numberOfArguments];
                if (numberOfArguments - 1 != expr.args.count) {
                    mf_throw_error(expr.lineNumber, MFRuntimeErrorParameterListCountNoMatch, @"expect count: %zd, pass in cout:%zd",numberOfArguments - 1,expr.args.count);
                    return;
                }
                for (NSUInteger i = 1; i < numberOfArguments; i++) {
                    const char *typeEncoding = [sig getArgumentTypeAtIndex:i];
                    void *ptr = alloca(mf_size_with_encoding(typeEncoding));
                    eval_expression(inter, scope, expr.args[i -1]);
                    __autoreleasing YTXMFValue *argValue = [inter.stack pop];
                    [argValue assignToCValuePointer:ptr typeEncoding:typeEncoding];
                    [invocation setArgument:ptr atIndex:i];
                }
                [invocation invoke];
                const char *retType = [sig methodReturnType];
                retType = removeTypeEncodingPrefix((char *)retType);
                YTXMFValue *retValue;
                if (*retType != 'v') {
                    void *retValuePtr = alloca(mf_size_with_encoding(retType));
                    [invocation getReturnValue:retValuePtr];
                    retValue = [[YTXMFValue alloc] initWithCValuePointer:retValuePtr typeEncoding:retType bridgeTransfer:NO];
                }else{
                    retValue = [YTXMFValue voidValueInstance];
                }
                [inter.stack push:retValue];
            }
			break;
		}
			
		default:
            mf_throw_error(expr.lineNumber, MFRuntimeErrorCallCanNotBeCalleeValue, @"expression can not be callee");
			break;
	}
	
}

static YTXMFValue * call_c_function(NSUInteger lineNumber, YTXMFValue *callee, NSArray<YTXMFValue *> *argValues){
    void *functionPtr = callee.pointerValue;
    NSArray<NSString *> *paramListTypeEncode = callee.type.paramListTypeEncode;
    NSString *returnTypeEncode = callee.type.returnTypeEncode;
    NSUInteger argCount = paramListTypeEncode.count;
    
    ffi_type **ffiArgTypes = alloca(sizeof(ffi_type *) *argCount);
    for (int i = 0; i < argCount; i++) {
        ffiArgTypes[i] = mf_ffi_type_with_type_encoding(paramListTypeEncode[i].UTF8String);
    }
    
    void **ffiArgs = alloca(sizeof(void *) *argCount);
    for (int  i = 0; i < argCount; i++) {
        size_t size = ffiArgTypes[i]->size;
        void *ffiArgPtr = alloca(size);
        ffiArgs[i] = ffiArgPtr;
        YTXMFValue *argValue = argValues[i];
        [argValue assignToCValuePointer:ffiArgPtr typeEncoding:paramListTypeEncode[i].UTF8String];
    }

    ffi_cif cif;
    ffi_type *returnFfiType = mf_ffi_type_with_type_encoding(returnTypeEncode.UTF8String);;
    ffi_status ffiPrepStatus = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)argCount, returnFfiType, ffiArgTypes);

    if (ffiPrepStatus == FFI_OK) {
        void *returnPtr = NULL;
        if (returnFfiType->size) {
            returnPtr = alloca(returnFfiType->size);
        }
        ffi_call(&cif, functionPtr, returnPtr, ffiArgs);

        YTXMFValue *value = [[YTXMFValue alloc] initWithCValuePointer:returnPtr typeEncoding:returnTypeEncode.UTF8String bridgeTransfer:NO];
        return value;
    }
    mf_throw_error(lineNumber, MFRuntimeErrorCallCFunctionFailure, @"call CFunction failure");
    return nil;
}


static void eval_cfunction_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFCFuntionExpression *expr){
    YTXMFExpression *cfunNameOrPointerExpr = expr.cfunNameOrPointerExpr;
    eval_expression(inter, scope, cfunNameOrPointerExpr);
    YTXMFValue *cfunNameOrPointer = [inter.stack pop];
    if (cfunNameOrPointer.type.typeKind != MF_TYPE_C_STRING && cfunNameOrPointer.type.typeKind != MF_TYPE_POINTER) {
        mf_throw_error(cfunNameOrPointerExpr.lineNumber, MFRuntimeErrorIllegalParameterType, @" CFuntion must accept a CString type or Pointer type, not %@!",cfunNameOrPointer.type.typeName);
        return;
    }
    
    YTXMFValue *value = [[YTXMFValue alloc] init];
    YTXMFTypeSpecifier *type = mf_create_type_specifier(MF_TYPE_C_FUNCTION);
    value.type = type;
    
    if (cfunNameOrPointer.type.typeKind == MF_TYPE_C_STRING) {
        void *pointerValue = NULL;
        if (!pointerValue) {
            mf_throw_error(cfunNameOrPointerExpr.lineNumber, MFRuntimeErrorNotFoundCFunction, @"not found CFunction: %s",cfunNameOrPointer.cstringValue);
            return;
        }
        value.pointerValue = pointerValue;
    }else{
        value.pointerValue = cfunNameOrPointer.pointerValue;
    }
    [inter.stack push:value];
}



static void eval_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope, __kindof YTXMFExpression *expr){
	switch (expr.expressionKind) {
		case MF_BOOLEAN_EXPRESSION:
			eval_bool_exprseeion(inter, expr);
			break;
        case MF_U_INT_EXPRESSION:
            eval_u_interger_expression(inter, expr);
            break;
		case MF_INT_EXPRESSION:
			eval_interger_expression(inter, expr);
			break;
		case MF_DOUBLE_EXPRESSION:
			eval_double_expression(inter, expr);
			break;
		case MF_STRING_EXPRESSION:
			eval_string_expression(inter, expr);
			break;
		case MF_SELECTOR_EXPRESSION:
			eval_sel_expression(inter, expr);
			break;
		case MF_BLOCK_EXPRESSION:
			eval_block_expression(inter, scope, expr);
			break;
		case MF_NIL_EXPRESSION:
			eval_nil_expr(inter);
			break;
		case MF_NULL_EXPRESSION:
			eval_null_expr(inter);
			break;
		case MF_SELF_EXPRESSION:
		case MF_SUPER_EXPRESSION:
			eval_self_super_expression(inter, scope);
			break;
		case MF_IDENTIFIER_EXPRESSION:
			eval_identifer_expression(inter, scope, expr);
			break;
		case MF_ASSIGN_EXPRESSION:
			eval_assign_expression(inter, scope, expr);
			break;
		case MF_ADD_EXPRESSION:
			eval_add_expression(inter, scope, expr);
			break;
		case MF_SUB_EXPRESSION:
			eval_sub_expression(inter, scope, expr);
			break;
		case MF_MUL_EXPRESSION:
			eval_mul_expression(inter, scope, expr);
			break;
		case MF_DIV_EXPRESSION:
			eval_div_expression(inter, scope, expr);
			break;
		case MF_MOD_EXPRESSION:
			eval_mod_expression(inter, scope, expr);
			break;
		case MF_EQ_EXPRESSION:
			eval_eq_expression(inter, scope, expr);
			break;
		case MF_NE_EXPRESSION:
			eval_ne_expression(inter, scope, expr);
			break;
		case MF_LT_EXPRESSION:
			eval_lt_expression(inter, scope, expr);
			break;
		case MF_LE_EXPRESSION:
			eval_le_expression(inter, scope, expr);
			break;
		case MF_GE_EXPRESSION:
			eval_ge_expression(inter, scope, expr);
			break;
		case MF_GT_EXPRESSION:
			eval_gt_expression(inter, scope, expr);
			break;
		case MF_LOGICAL_AND_EXPRESSION:
			eval_logic_and_expression(inter, scope, expr);
			break;
		case MF_LOGICAL_OR_EXPRESSION:
			eval_logic_or_expression(inter, scope, expr);
			break;
		case MF_LOGICAL_NOT_EXPRESSION:
			eval_logic_not_expression(inter, scope, expr);
			break;
		case MF_TERNARY_EXPRESSION:
			eval_ternary_expression(inter, scope, expr);
			break;
		case MF_SUB_SCRIPT_EXPRESSION:
			eval_sub_script_expression(inter, scope, expr);
			break;
		case MF_AT_EXPRESSION:
			eval_at_expression(inter, scope, expr);
			break;
        case MF_GET_ADDRESS_EXPRESSION:
            eval_get_address_expresion(inter, scope, expr);
            break;
		case NSC_NEGATIVE_EXPRESSION:
			eval_negative_expression(inter, scope, expr);
			break;
		case MF_MEMBER_EXPRESSION:
			eval_member_expression(inter, scope, expr);
			break;
		case MF_DIC_LITERAL_EXPRESSION:
			eval_dic_expression(inter, scope, expr);
			break;
		case MF_ARRAY_LITERAL_EXPRESSION:
			eval_array_expression(inter, scope, expr);
			break;
		case MF_INCREMENT_EXPRESSION:
			eval_increment_expression(inter, scope, expr);
			break;
		case MF_DECREMENT_EXPRESSION:
			eval_decrement_expression(inter, scope, expr);
			break;
		case MF_STRUCT_LITERAL_EXPRESSION:
			eval_struct_expression(inter, scope, expr);
			break;
		case MF_FUNCTION_CALL_EXPRESSION:
			eval_function_call_expression(inter, scope, expr);
			break;
        case MF_C_FUNCTION_EXPRESSION:
            eval_cfunction_expression(inter, scope, expr);
            break;
		default:
			break;
	}
	
}

YTXMFValue *mf_eval_expression(YTXMFInterpreter *inter, YTXMFScopeChain *scope,YTXMFExpression *expr){
	eval_expression(inter, scope, expr);
	return [inter.stack pop];
}

