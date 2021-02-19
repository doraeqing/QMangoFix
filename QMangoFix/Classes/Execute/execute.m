//
//  execute.m
//  MangoFix
//
//  Created by jerry.yong on 2017/12/25.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//
//typedef <#existing#> <#new#>;
#import <UIKit/UIKit.h>
#include <string.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "create.h"
#import "execute.h"
#import "util.h"
#import "ffi.h"
#import "runenv.h"
#import "YTXMFValue+Private.h"
#import "YTXMFWeakPropertyBox.h"
#import "YTXMFPropertyMapTable.h"
#import "YTXMFStaticVarTable.h"

const void *mf_propKey(NSString *propName) {
    static NSMutableDictionary *_propKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _propKeys = [[NSMutableDictionary alloc] init];
    });
	id key = _propKeys[propName];
	if (!key) {
		key = [propName copy];
		[_propKeys setObject:key forKey:propName];
	}
	return (__bridge const void *)(key);
}


static YTXMFValue *default_value_with_type_specifier( YTXMFTypeSpecifier *typeSpecifier,MFDeclarationModifier modifier){
    YTXMFValue *value = [[YTXMFValue alloc] init];
    value.modifier = modifier;
    value.type = typeSpecifier;
    if (typeSpecifier.typeKind == MF_TYPE_STRUCT) {
        size_t size = mf_size_with_encoding([typeSpecifier typeEncoding]);
        value.pointerValue = malloc(size);
    }
    return value;
}



static void execute_declaration(YTXMFInterpreter *inter, YTXMFScopeChain *scope, YTXMFDeclaration *declaration){
    BOOL staticVar = declaration.modifier & MFDeclarationModifierStatic;
    __block YTXMFValue *value = nil;
    
    void (^initValueBlock)(void) = ^(){
        value = default_value_with_type_specifier(declaration.type,declaration.modifier);
        if (declaration.initializer) {
            YTXMFValue *initValue = mf_eval_expression(inter, scope, declaration.initializer);
            [value assignFrom:initValue];
        }
    };
    
    if (staticVar) {
        NSString *key = [NSString stringWithFormat:@"%p",(void *)declaration];
        value = [[YTXMFStaticVarTable shareInstance] getStaticVarValueWithKey:key];
        if (value) {
            [scope setValue:value withIndentifier:declaration.name];
        }else{
            initValueBlock();
            [scope setValue:value withIndentifier:declaration.name];
            [[YTXMFStaticVarTable shareInstance] setStaticVarValue:value withKey:key];
        }
    }else{
        initValueBlock();
        [scope setValue:value withIndentifier:declaration.name];
    }
	
}


static YTXMFStatementResult *execute_else_if_list(YTXMFInterpreter *inter, YTXMFScopeChain *scope,NSArray<MFElseIf *> *elseIfList,BOOL *executed){
	YTXMFStatementResult *res;
	*executed = NO;
	for (MFElseIf *elseIf in elseIfList) {
		YTXMFValue *conValue = mf_eval_expression(inter, scope, elseIf.condition);
		if ([conValue isSubtantial]) {
			YTXMFScopeChain *elseIfScope = [YTXMFScopeChain scopeChainWithNext:scope];
			res = mf_execute_statement_list(inter, elseIfScope, elseIf.thenBlock.statementList);
			[elseIfScope setMangoBlockVarNil];
			*executed = YES;
			break;
		}
	}
	return res ?: [YTXMFStatementResult normalResult];
}


static YTXMFStatementResult *execute_if_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFIfStatement *statement){
	YTXMFStatementResult *res;
	YTXMFValue *conValue = mf_eval_expression(inter, scope, statement.condition);
	if ([conValue isSubtantial]) {
		YTXMFScopeChain *thenScope = [YTXMFScopeChain scopeChainWithNext:scope];
		res = mf_execute_statement_list(inter, thenScope, statement.thenBlock.statementList);
		[thenScope setMangoBlockVarNil];
	}else{
		BOOL executed;
		res = execute_else_if_list(inter, scope, statement.elseIfList, &executed);
		if (!executed && statement.elseBlocl) {
			YTXMFScopeChain *elseScope = [YTXMFScopeChain scopeChainWithNext:scope];
			res = mf_execute_statement_list(inter, elseScope, statement.elseBlocl.statementList);
			[elseScope setMangoBlockVarNil];
		}
	}
	return res ?: [YTXMFStatementResult normalResult];
	
}


static YTXMFStatementResult *execute_switch_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFSwitchStatement *statement){
	YTXMFStatementResult *res;
	YTXMFValue *value = mf_eval_expression(inter, scope, statement.expr);
	BOOL hasMatch = NO;
	for (MFCase *case_ in statement.caseList) {
		if (!hasMatch) {
			YTXMFValue *caseValue = mf_eval_expression(inter, scope, case_.expr);
			BOOL equal = mf_equal_value(case_.expr.lineNumber, value, caseValue);
			if (equal) {
				hasMatch = YES;
			}else{
				continue;
			}
		}
		YTXMFScopeChain *caseScope = [YTXMFScopeChain scopeChainWithNext:scope];
		res = mf_execute_statement_list(inter, caseScope, case_.block.statementList);
		[caseScope setMangoBlockVarNil];
		if (res.type != MFStatementResultTypeNormal) {
			break;
		}
	}
	res = res ?: [YTXMFStatementResult normalResult];
	if (res.type == MFStatementResultTypeNormal) {
		YTXMFScopeChain *defaultCaseScope = [YTXMFScopeChain scopeChainWithNext:scope];
		res = mf_execute_statement_list(inter, defaultCaseScope, statement.defaultBlock.statementList);
		[defaultCaseScope setMangoBlockVarNil];
	}
	
	if (res.type == MFStatementResultTypeBreak) {
		res.type = MFStatementResultTypeNormal;
	}
	
	return res;
}



static YTXMFStatementResult *execute_for_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFForStatement *statement){
	YTXMFStatementResult *res;
	YTXMFScopeChain *forScope = [YTXMFScopeChain scopeChainWithNext:scope];
	if (statement.initializerExpr) {
		mf_eval_expression(inter, forScope, statement.initializerExpr);
	}else if (statement.declaration){
		execute_declaration(inter, forScope, statement.declaration);
	}
	
	for (;;) {
		YTXMFValue *conValue = mf_eval_expression(inter, forScope, statement.condition);
		if (![conValue isSubtantial]) {
			break;
		}
		res = mf_execute_statement_list(inter, forScope, statement.block.statementList);
		if (res.type == MFStatementResultTypeReturn) {
			break;
		}else if (res.type == MFStatementResultTypeBreak) {
			res.type = MFStatementResultTypeNormal;
			break;
		}else if (res.type == MFStatementResultTypeContinue){
			res.type = MFStatementResultTypeNormal;
		}
		if (statement.post) {
			mf_eval_expression(inter, forScope, statement.post);
		}
		
	}
	
	[forScope setMangoBlockVarNil];
	
	return res ?: [YTXMFStatementResult normalResult];
	
}


static YTXMFStatementResult *execute_for_each_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope, MFForEachStatement *statement){
	YTXMFStatementResult *res;
	YTXMFScopeChain *forScope = [YTXMFScopeChain scopeChainWithNext:scope];

	if (statement.declaration) {
		execute_declaration(inter, forScope, statement.declaration);
		MFIdentifierExpression *identifierExpr = [[MFIdentifierExpression alloc] init];
		identifierExpr.expressionKind = MF_IDENTIFIER_EXPRESSION;
		identifierExpr.identifier = statement.declaration.name;
		statement.identifierExpr = identifierExpr;
	}
	
	YTXMFValue *arrValue = mf_eval_expression(inter, scope, statement.collectionExpr);
	if (arrValue.type.typeKind != MF_TYPE_OBJECT) {
		NSCAssert(0, @"");
	}
	
	for (id var in arrValue.objectValue) {
		YTXMFValue *operValue = [[YTXMFValue alloc] init];
		operValue.type = mf_create_type_specifier(MF_TYPE_OBJECT);
		operValue.objectValue = var;
		[forScope assignWithIdentifer:statement.identifierExpr.identifier value:operValue];
		
		res = mf_execute_statement_list(inter, forScope, statement.block.statementList);
		if (res.type == MFStatementResultTypeReturn) {
			break;
		}else if (res.type == MFStatementResultTypeBreak) {
			res.type = MFStatementResultTypeNormal;
			break;
		}else if (res.type == MFStatementResultTypeContinue){
			res.type = MFStatementResultTypeNormal;
		}
	}
	[forScope setMangoBlockVarNil];
	return res ?: [YTXMFStatementResult normalResult];
}


static YTXMFStatementResult *execute_while_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope,  MFWhileStatement *statement){
	YTXMFStatementResult *res;
	YTXMFScopeChain *whileScope = [YTXMFScopeChain scopeChainWithNext:scope];
	for (;;) {
		YTXMFValue *conValue = mf_eval_expression(inter, whileScope, statement.condition);
		if (![conValue isSubtantial]) {
			break;
		}
		res = mf_execute_statement_list(inter, whileScope, statement.block.statementList);
		if (res.type == MFStatementResultTypeReturn) {
			break;
		}else if (res.type == MFStatementResultTypeBreak) {
			res.type = MFStatementResultTypeNormal;
			break;
		}else if (res.type == MFStatementResultTypeContinue){
			res.type = MFStatementResultTypeNormal;
		}
	}
	[whileScope setMangoBlockVarNil];
	return res ?: [YTXMFStatementResult normalResult];
}


static YTXMFStatementResult *execute_do_while_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope,  MFDoWhileStatement *statement){
	YTXMFStatementResult *res;
	YTXMFScopeChain *whileScope = [YTXMFScopeChain scopeChainWithNext:scope];
	for (;;) {
		res = mf_execute_statement_list(inter, whileScope, statement.block.statementList);
		if (res.type == MFStatementResultTypeReturn) {
			break;
		}else if (res.type == MFStatementResultTypeBreak) {
			res.type = MFStatementResultTypeNormal;
			break;
		}else if (res.type == MFStatementResultTypeContinue){
			res.type = MFStatementResultTypeNormal;
		}
		YTXMFValue *conValue = mf_eval_expression(inter, whileScope, statement.condition);
		if (![conValue isSubtantial]) {
			break;
		}
	}
	[whileScope setMangoBlockVarNil];
	return res ?: [YTXMFStatementResult normalResult];
}


static YTXMFStatementResult *execute_return_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope,  MFReturnStatement *statement){
	YTXMFStatementResult *res = [YTXMFStatementResult returnResult];
	if (statement.retValExpr) {
		res.reutrnValue = mf_eval_expression(inter, scope, statement.retValExpr);
	}else{
		res.reutrnValue = [YTXMFValue voidValueInstance];
	}
	return res;
}


static YTXMFStatementResult *execute_break_statement(){
	return [YTXMFStatementResult breakResult];
}


static YTXMFStatementResult *execute_continue_statement(){
	return [YTXMFStatementResult continueResult];
}


static  YTXMFStatementResult *execute_statement(YTXMFInterpreter *inter, YTXMFScopeChain *scope, __kindof YTXMFStatement *statement){
	YTXMFStatementResult *res;
	switch (statement.kind) {
		case MFStatementKindExpression:
			mf_eval_expression(inter, scope, [(MFExpressionStatement *)statement expr]);
			res = [YTXMFStatementResult normalResult];
			break;
		case MFStatementKindDeclaration:{
			execute_declaration(inter, scope, [(MFDeclarationStatement *)statement declaration]);
			res = [YTXMFStatementResult normalResult];
			break;
		}
		case MFStatementKindIf:{
			res = execute_if_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindSwitch:{
			res = execute_switch_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindFor:{
			res = execute_for_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindForEach:{
			res = execute_for_each_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindWhile:{
			res = execute_while_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindDoWhile:{
			res = execute_do_while_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindReturn:{
			res = execute_return_statement(inter, scope, statement);
			break;
		}
		case MFStatementKindBreak:{
			res = execute_break_statement();
			break;
		}
		case MFStatementKindContinue:{
			res = execute_continue_statement();
			break;
		}
			
		default:
			break;
	}
	return res;
}


YTXMFStatementResult *mf_execute_statement_list(YTXMFInterpreter *inter, YTXMFScopeChain *scope, NSArray<YTXMFStatement *> *statementList){
	YTXMFStatementResult *result;
	if (statementList.count) {
		for (YTXMFStatement *statement in statementList) {
			result = execute_statement(inter, scope, statement);
			if (result.type != MFStatementResultTypeNormal) {
				break;
			}
		}
	}else{
		result = [YTXMFStatementResult normalResult];
	}
	return result;
}


YTXMFValue * mf_call_mf_function(YTXMFInterpreter *inter, YTXMFScopeChain *scope, YTXMFFunctionDefinition *func, NSArray<YTXMFValue *> *args){
	NSArray<MFParameter *> *params = func.params;
	if (params.count != args.count) {
        mf_throw_error(func.lineNumber, MFRuntimeErrorParameterListCountNoMatch, @"expect count: %zd, pass in cout:%zd",params.count, args.count);
        return nil;
	}
	YTXMFScopeChain *funScope = [YTXMFScopeChain scopeChainWithNext:scope];
	NSUInteger i = 0;
	for (MFParameter *param in params) {
		[funScope setValue:args[i] withIndentifier:param.name];
		i++;
	}
	
	YTXMFStatementResult *res = mf_execute_statement_list(inter, funScope, func.block.statementList);
	[funScope setMangoBlockVarNil];
	if (res.type == MFStatementResultTypeReturn) {
		return res.reutrnValue;
	}else{
		return [YTXMFValue voidValueInstance];
	}
}


static void define_class(YTXMFInterpreter *interpreter,YTXMFClassDefinition *classDefinition){
	if (classDefinition.annotationIfExprResult == AnnotationIfExprResultNoComputed) {
		YTXMFExpression *annotationIfConditionExpr = classDefinition.annotationIfConditionExpr;
		if (annotationIfConditionExpr) {
			YTXMFValue *value = mf_eval_expression(interpreter, interpreter.topScope, annotationIfConditionExpr);
			classDefinition.annotationIfExprResult = value.isSubtantial ? AnnotationIfExprResultTrue : AnnotationIfExprResultFalse;
			if (!value.isSubtantial) {
				return;
			}
		}else{
			classDefinition.annotationIfExprResult = AnnotationIfExprResultTrue;
		}
	}
	
	
	if (classDefinition.annotationIfExprResult != AnnotationIfExprResultTrue) {
		return;
	}
	
	Class clazz = NSClassFromString(classDefinition.name);
	if (!clazz) {
		NSString *superClassName = classDefinition.superNmae;
		Class superClass = NSClassFromString(superClassName);
		if (!superClass) {
			define_class(interpreter, interpreter.classDefinitionDic[superClassName]);
		}
		
		if (!superClass) {
            mf_throw_error(classDefinition.lineNumber, MFRuntimeErrorNotFoundSuperClass, @"not found super class: %@",superClassName);
			return;
		}
		Class clazz = objc_allocateClassPair(superClass, classDefinition.name.UTF8String, 0);
		objc_registerClassPair(clazz);
	}else{
		Class superClass = class_getSuperclass(clazz);
		char const *superClassName = class_getName(superClass);
		if (strcmp(classDefinition.superNmae.UTF8String, superClassName)) {
            mf_throw_error(classDefinition.lineNumber, @"MFRuntimeErrorSuperClassNoMatch", @"MangoFix class: %@:%@, but Objective-C class: %@:%s",classDefinition.name,classDefinition.superNmae, classDefinition.name, superClassName);
			return;
		}
	}
}



void getterInter(ffi_cif *cif, void *ret, void **args, void *userdata){
	MFPropertyDefinition *propDef = (__bridge MFPropertyDefinition *)userdata;
	id _self = (__bridge id)(*(void **)args[0]);
	NSString *propName = propDef.name;
	id propValue = objc_getAssociatedObject(_self, mf_propKey(propName));
	const char *type = [propDef.typeSpecifier typeEncoding];
    __autoreleasing YTXMFValue *value;
	if (!propValue) {
		value = [YTXMFValue defaultValueWithTypeEncoding:type];
		[value assignToCValuePointer:ret typeEncoding:type];
	}else if(*type == '@'){
        if ([propValue isKindOfClass:[YTXMFWeakPropertyBox class]]) {
            YTXMFWeakPropertyBox *box = propValue;
            if (box.target) {
                *(void **)ret = (__bridge void *)box.target;
            }else{
                value = [YTXMFValue defaultValueWithTypeEncoding:type];
                [value assignToCValuePointer:ret typeEncoding:type];
            }
        }else{
            *(void **)ret = (__bridge void *)propValue;
        }
	}else{
		value = propValue;
		[value assignToCValuePointer:ret typeEncoding:type];
	}
	
	
}


void setterInter(ffi_cif *cif, void *ret, void **args, void *userdata){
	MFPropertyDefinition *propDef = (__bridge MFPropertyDefinition *)userdata;
	id _self = (__bridge id)(*(void **)args[0]);
	const char *type = [propDef.typeSpecifier typeEncoding];
	id value;
	if (*type == '@') {
		value = (__bridge id)(*(void **)args[2]);
	}else{
		value = [[YTXMFValue alloc] initWithCValuePointer:args[2] typeEncoding:type bridgeTransfer:NO];
	}
	NSString *propName = propDef.name;
	
    MFPropertyModifier modifier = propDef.modifier;
    if ((modifier & MFPropertyModifierMemMask) == MFPropertyModifierMemWeak) {
        value = [[YTXMFWeakPropertyBox alloc] initWithTarget:value];
    }
	objc_AssociationPolicy associationPolicy = mf_AssociationPolicy_with_PropertyModifier(modifier);
	objc_setAssociatedObject(_self, mf_propKey(propName), value, associationPolicy);
    
}

static void replace_getter_method(NSUInteger lineNumber, YTXMFInterpreter *inter ,Class clazz, MFPropertyDefinition *prop){
	SEL getterSEL = NSSelectorFromString(prop.name);
	const char *retTypeEncoding  = [prop.typeSpecifier typeEncoding];
	ffi_type *returnType = mf_ffi_type_with_type_encoding(retTypeEncoding);
	unsigned int argCount = 2;
	ffi_type **argTypes = malloc(sizeof(ffi_type *) * argCount);
	argTypes[0] = &ffi_type_pointer;
	argTypes[1] = &ffi_type_pointer;


	void *imp = NULL;
	ffi_cif *cifPtr = malloc(sizeof(ffi_cif));
	ffi_prep_cif(cifPtr, FFI_DEFAULT_ABI, argCount, returnType, argTypes);
	ffi_closure *closure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&imp);
	ffi_prep_closure_loc(closure, cifPtr, getterInter, (__bridge void *)prop, imp);
	NSString * typeEncoding = [NSString stringWithFormat:@"%s%s",retTypeEncoding, "@:"];
	class_replaceMethod(clazz, getterSEL, (IMP)imp, typeEncoding.UTF8String);
}

static void replace_setter_method(NSUInteger lineNumber ,YTXMFInterpreter *inter ,Class clazz, MFPropertyDefinition *prop){
	NSString *str1 = [[prop.name substringWithRange:NSMakeRange(0, 1)] uppercaseString];
	NSString *str2 = prop.name.length > 1 ? [prop.name substringFromIndex:1] : nil;
	SEL setterSEL = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",str1,str2]);
	const char *prtTypeEncoding  = [prop.typeSpecifier typeEncoding];
	ffi_type *returnType = &ffi_type_void;
	unsigned int argCount = 3;
	ffi_type **argTypes = malloc(sizeof(ffi_type *) * argCount);
	argTypes[0] = &ffi_type_pointer;
	argTypes[1] = &ffi_type_pointer;
	argTypes[2] = mf_ffi_type_with_type_encoding([prop.typeSpecifier typeEncoding]);
	if (argTypes[2] == NULL) {
        mf_throw_error(lineNumber, @"", @"");
	}

	void *imp = NULL;
	ffi_cif *cifPtr = malloc(sizeof(ffi_cif));
	ffi_prep_cif(cifPtr, FFI_DEFAULT_ABI, argCount, returnType, argTypes);
	ffi_closure *closure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&imp);
	ffi_prep_closure_loc(closure, cifPtr, setterInter, (__bridge void *)prop, imp);
	NSString * typeEncoding = [NSString stringWithFormat:@"%s%s","v@:", prtTypeEncoding];
	class_replaceMethod(clazz, setterSEL, (IMP)imp, typeEncoding.UTF8String);
}



static void replace_prop(YTXMFInterpreter *inter ,Class clazz, MFPropertyDefinition *prop){
	if (prop.annotationIfConditionExpr) {
		YTXMFValue *conValue = mf_eval_expression(inter, inter.topScope, prop.annotationIfConditionExpr);
		if (![conValue isSubtantial]) {
			return;
		}
	}
	
	objc_property_attribute_t type = {"T", [prop.typeSpecifier typeEncoding]};
	objc_property_attribute_t memAttr = {"",""};
	switch (prop.modifier & MFPropertyModifierMemMask) {
		case MFPropertyModifierMemStrong:
			memAttr.name = "&";
			break;
		case MFPropertyModifierMemWeak:
			memAttr.name = "W";
			break;
		case MFPropertyModifierMemCopy:
			memAttr.name = "C";
			break;
		default:
			break;
	}
	
	objc_property_attribute_t atomicAttr = {"",""};
	switch (prop.modifier & MFPropertyModifierAtomicMask) {
		case MFPropertyModifierAtomic:
			break;
		case MFPropertyModifierNonatomic:
			atomicAttr.name = "N";
			break;
		default:
			break;
	}
	objc_property_attribute_t attrs[] = { type, memAttr, atomicAttr };
	class_replaceProperty(clazz, prop.name.UTF8String, attrs, 3);
    MFPropertyMapTableItem *propItem = [[MFPropertyMapTableItem alloc] initWithClass:clazz property:prop];
    [[YTXMFPropertyMapTable shareInstance] addPropertyMapTableItem:propItem];
	replace_getter_method(prop.lineNumber, inter, clazz, prop);
	replace_setter_method(prop.lineNumber ,inter, clazz, prop);
	
}


static void replaceIMP(ffi_cif *cif, void *ret, void **args, void *userdata){
    
    NSDictionary * userInfo = (__bridge id)userdata;// 不可以进行释放
    Class class  = userInfo[@"class"];
    NSString *typeEncoding = userInfo[@"typeEncoding"];
    id assignSlf = (__bridge  id)(*(void **)args[0]);
    SEL sel = *(void **)args[1];

    BOOL classMethod = object_isClass(assignSlf);
    MFMethodMapTableItem *map = [[YTXMFMethodMapTable shareInstance] getMethodMapTableItemWith:class classMethod:classMethod sel:sel];
    MFMethodDefinition *method = map.method;
    YTXMFInterpreter *inter = map.inter;

    YTXMFScopeChain *classScope = [YTXMFScopeChain scopeChainWithNext:inter.topScope];
    classScope.instance = assignSlf;

    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:typeEncoding.UTF8String];


    NSMutableArray<YTXMFValue *> *argValues = [NSMutableArray array];
    NSUInteger numberOfArguments = [methodSignature numberOfArguments];
    for (NSUInteger i = 0; i < numberOfArguments; i++) {
        YTXMFValue *argValue;
        const char *type = [methodSignature getArgumentTypeAtIndex:i];
        if (strcmp(type, "@?") == 0) {
            id block =  (__bridge id)(*(void **)args[i]);
            block = [block copy];
            argValue = [YTXMFValue valueInstanceWithObject:block];
        }else{
            void *arg = args[i];
            argValue = [[YTXMFValue alloc] initWithCValuePointer:arg typeEncoding:[methodSignature getArgumentTypeAtIndex:i] bridgeTransfer:NO];
        }
        
        [argValues addObject:argValue];
    }
    __autoreleasing YTXMFValue *retValue = mf_call_mf_function(inter, classScope, method.functionDefinition, argValues);
    [retValue assignToCValuePointer:ret typeEncoding:[methodSignature methodReturnType]];
}


static void replace_method(YTXMFInterpreter *interpreter,Class clazz, MFMethodDefinition *method){
	if (method.annotationIfConditionExpr) {
		YTXMFValue *conValue = mf_eval_expression(interpreter, interpreter.topScope, method.annotationIfConditionExpr);
		if (![conValue isSubtantial]) {
			return;
		}
	}
	YTXMFFunctionDefinition *func = method.functionDefinition;
	SEL sel = NSSelectorFromString(func.name);
	
	MFMethodMapTableItem *item = [[MFMethodMapTableItem alloc] initWithClass:clazz inter:interpreter method:method];
	[[YTXMFMethodMapTable shareInstance] addMethodMapTableItem:item];
	
	NSMutableString *typeEncoding = [NSMutableString string];
	Method ocMethod;
	if (method.classMethod) {
		ocMethod = class_getClassMethod(clazz, sel);
	}else{
		ocMethod = class_getInstanceMethod(clazz, sel);
	}
	
	if (ocMethod) {
		[typeEncoding appendString:@(method_getTypeEncoding(ocMethod))];
	}else{
		[typeEncoding appendString:@([func.returnTypeSpecifier typeEncoding])];
		
		for (MFParameter *param in func.params) {
			const char *paramTypeEncoding = [param.type typeEncoding];
            [typeEncoding appendString:@(paramTypeEncoding)];
		}
	}
	Class c2 = method.classMethod ? objc_getMetaClass(class_getName(clazz)) : clazz;
    if (class_respondsToSelector(c2, sel)) {
        NSString *orgSelName = [NSString stringWithFormat:@"ORG%@",func.name];
        SEL orgSel = NSSelectorFromString(orgSelName);
        if (!class_respondsToSelector(c2, orgSel)) {
            class_addMethod(c2, orgSel, method_getImplementation(ocMethod), typeEncoding.UTF8String);
        }
    }
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:typeEncoding.UTF8String];
    unsigned int argCount = (unsigned int)[sig numberOfArguments];
    void *imp = NULL;
    ffi_cif *cif = malloc(sizeof(ffi_cif));//不可以free
    ffi_closure *closure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&imp);
    ffi_type *returnType = mf_ffi_type_with_type_encoding(sig.methodReturnType);
    ffi_type **args = malloc(sizeof(ffi_type *) * argCount);
    for (int  i = 0 ; i < argCount; i++) {
        args[i] = mf_ffi_type_with_type_encoding([sig getArgumentTypeAtIndex:i]);
    }

    if(ffi_prep_cif(cif, FFI_DEFAULT_ABI, argCount, returnType, args) == FFI_OK)
    {
        NSDictionary *userInfo = @{@"class":c2,@"typeEncoding":[typeEncoding copy]};
        CFTypeRef cfuserInfo = (__bridge_retained CFTypeRef)userInfo;
        ffi_prep_closure_loc(closure, cif, replaceIMP, (void *)cfuserInfo, imp);
    }
    class_replaceMethod(c2, sel, imp, typeEncoding.UTF8String);
}


static void fix_class(YTXMFInterpreter *interpreter,YTXMFClassDefinition *classDefinition){
	Class clazz = NSClassFromString(classDefinition.name);
	for (MFPropertyDefinition *prop in classDefinition.properties) {
		replace_prop(interpreter,clazz, prop);
	}
	
	for (MFMethodDefinition *classMethod in classDefinition.classMethods) {
		replace_method(interpreter, clazz, classMethod);
	}
	
	for (MFMethodDefinition *instanceMethod in classDefinition.instanceMethods) {
		replace_method(interpreter, clazz, instanceMethod);
	}
}


void add_struct_declare(YTXMFInterpreter *interpreter, YTXMFStructDeclare *structDeclaer){
	if (structDeclaer.annotationIfConditionExpr) {
		YTXMFValue *conValue = mf_eval_expression(interpreter, interpreter.topScope, structDeclaer.annotationIfConditionExpr);
		if (![conValue isSubtantial]) {
			return;
		}
	}
	YTXMFStructDeclareTable *table = [YTXMFStructDeclareTable shareInstance];
	[table addStructDeclare:structDeclaer];
}




void mf_interpret(YTXMFInterpreter *interpreter){
	for (__kindof NSObject *top in interpreter.topList) {
		if ([top isKindOfClass:[YTXMFStatement class]]) {
			execute_statement(interpreter, interpreter.topScope, top);
		}else if ([top isKindOfClass:[YTXMFStructDeclare class]]){
			add_struct_declare(interpreter,top);
		}else if ([top isKindOfClass:[YTXMFClassDefinition class]]){
			define_class(interpreter, top);
			fix_class(interpreter,top);
		}
	}
}
