//
//  create.c
//  MangoFix
//
//  Created by Superdan on 2017/11/1.
//  Copyright © 2017年 xiaodongdan. All rights reserved.
//

#import "create.h"
#import "YTXMFStructDeclareTable.h"

#define STRING_ALLOC_SIZE (256)
static char *st_string_literal_buffer = NULL;
static int st_string_literal_buffer_size = 0;
static int st_string_literal_buffer_alloc_size = 0;


YTXMFInterpreter *mf_get_current_compile_util(){
    return  [NSThread currentThread].threadDictionary[@"current_compile_util"];
}


void mf_set_current_compile_util(YTXMFInterpreter *interpreter){
    if (!interpreter) {
        [[NSThread currentThread].threadDictionary removeObjectForKey:@"current_compile_util"];
    }else{
        [NSThread currentThread].threadDictionary[@"current_compile_util"] = interpreter;
    }
}


NSString *mf_create_identifier(char *str){
	NSString *ocStr = [NSString stringWithUTF8String:str];
	return ocStr;
}


void mf_open_string_literal_buf(){
	st_string_literal_buffer_size = 0;
}


void mf_append_string_literal(int letter){
	if (st_string_literal_buffer_size >= st_string_literal_buffer_alloc_size) {
		st_string_literal_buffer_alloc_size +=  STRING_ALLOC_SIZE;
		char *new_pointer = calloc(st_string_literal_buffer_alloc_size,1);
        memcpy(new_pointer, st_string_literal_buffer, st_string_literal_buffer_size);
		free(st_string_literal_buffer);
		st_string_literal_buffer = new_pointer;
	}
	st_string_literal_buffer[st_string_literal_buffer_size] = letter;
	st_string_literal_buffer_size++;
}


void mf_rest_string_literal_buffer(void){
	free(st_string_literal_buffer);
	st_string_literal_buffer = NULL;
	st_string_literal_buffer_size = 0;
	st_string_literal_buffer_alloc_size = 0;
}


const char *mf_end_string_literal(){
	mf_append_string_literal('\0');
	size_t strLen = strlen(st_string_literal_buffer);
	char *str = calloc(strLen + 1, 1);
	strcpy(str, st_string_literal_buffer);
	mf_rest_string_literal_buffer();
	return str;
}


Class mf_expression_class_of_kind(MFExpressionKind kind){
	switch (kind) {
		case MF_BOOLEAN_EXPRESSION:
		case MF_INT_EXPRESSION:
		case MF_U_INT_EXPRESSION:
		case MF_DOUBLE_EXPRESSION:
		case MF_STRING_EXPRESSION:
		case MF_SELF_EXPRESSION:
		case MF_SELECTOR_EXPRESSION:
		case MF_SUPER_EXPRESSION:
		case MF_NIL_EXPRESSION:
			return [YTXMFExpression class];
		case MF_IDENTIFIER_EXPRESSION:
			return [MFIdentifierExpression class];
		case MF_BLOCK_EXPRESSION:
			return [MFBlockExpression class];
		case MF_ASSIGN_EXPRESSION:
			return [MFAssignExpression class];
		case MF_TERNARY_EXPRESSION:
			return [MFTernaryExpression class];
		case MF_ADD_EXPRESSION:
		case MF_SUB_EXPRESSION:
		case MF_MUL_EXPRESSION:
		case MF_DIV_EXPRESSION:
		case MF_MOD_EXPRESSION:
		case MF_EQ_EXPRESSION:
		case MF_NE_EXPRESSION:
		case MF_GT_EXPRESSION:
		case MF_GE_EXPRESSION:
		case MF_LT_EXPRESSION:
		case MF_LE_EXPRESSION:
		case MF_LOGICAL_AND_EXPRESSION:
		case MF_LOGICAL_OR_EXPRESSION:
			return [MFBinaryExpression class];
		case MF_LOGICAL_NOT_EXPRESSION:
		case MF_INCREMENT_EXPRESSION:
		case MF_DECREMENT_EXPRESSION:
		case NSC_NEGATIVE_EXPRESSION:
        case MF_GET_ADDRESS_EXPRESSION:
		case MF_AT_EXPRESSION:
			return [MFUnaryExpression class];
		case MF_SUB_SCRIPT_EXPRESSION:
			return [MFSubScriptExpression class];
		case MF_MEMBER_EXPRESSION:
			return [MFMemberExpression class];
		case MF_FUNCTION_CALL_EXPRESSION:
			return [MFFunctonCallExpression class];
		case MF_DIC_LITERAL_EXPRESSION:
			return [MFDictionaryExpression class];
		case MF_STRUCT_LITERAL_EXPRESSION:
			return [MFStructpression class];
		case MF_ARRAY_LITERAL_EXPRESSION:
			return [MFArrayExpression class];
        case MF_C_FUNCTION_EXPRESSION:
            return [MFCFuntionExpression class];
		default:
			return [YTXMFExpression class];
	}
}


MFStructEntry *mf_create_struct_entry(NSString *key, YTXMFExpression *valueExpr){
	MFStructEntry *structEntry = [[MFStructEntry alloc] init];
	structEntry.key = key;
	structEntry.valueExpr = valueExpr;
	return structEntry;
}


MFDicEntry *mf_create_dic_entry(YTXMFExpression *keyExpr, YTXMFExpression *valueExpr){
	MFDicEntry *dicEntry = [[MFDicEntry alloc] init];
	dicEntry.keyExpr = keyExpr;
	dicEntry.valueExpr = valueExpr;
	return dicEntry;
}


YTXMFExpression *mf_create_expression(MFExpressionKind kind){
        Class clazz = mf_expression_class_of_kind(kind);
        YTXMFExpression *expr = [[clazz alloc] init];
        expr.lineNumber = mf_get_current_compile_util().currentLineNumber;
        expr.expressionKind = kind;
        if (mf_get_current_compile_util().currentClassDefinition) {
            expr.currentClassName = mf_get_current_compile_util().currentClassDefinition.name;
        }
        return expr;
}


void mf_build_block_expr(MFBlockExpression *expr, YTXMFTypeSpecifier *returnTypeSpecifier, NSArray<MFParameter *> *params, YTXMFBlockBody *block){
	YTXMFFunctionDefinition *func = [[YTXMFFunctionDefinition alloc] init];
    func.lineNumber = mf_get_current_compile_util().currentLineNumber;
	func.kind = MFFunctionDefinitionKindBlock;
	if (!returnTypeSpecifier) {
		returnTypeSpecifier = mf_create_type_specifier(MF_TYPE_VOID);
	}
	func.returnTypeSpecifier = returnTypeSpecifier;
	func.params  = params;
	func.block = block;
	expr.func = func;
}


YTXMFDeclaration *mf_create_declaration(MFDeclarationModifier modifier_list, YTXMFTypeSpecifier *type, NSString *name, YTXMFExpression *initializer){
	YTXMFDeclaration *declaration = [[YTXMFDeclaration alloc] init];
    declaration.lineNumber =  mf_get_current_compile_util().currentLineNumber;
    declaration.modifier = modifier_list;
	declaration.type = type;
	declaration.name = name;
	declaration.initializer = initializer;
	return declaration;
}


MFDeclarationStatement *mf_create_declaration_statement(YTXMFDeclaration *declaration){
	MFDeclarationStatement *statement = [[MFDeclarationStatement alloc] init];
	statement.kind = MFStatementKindDeclaration;
	statement.declaration = declaration;
	return statement;
}


MFExpressionStatement *mf_create_expression_statement(YTXMFExpression *expr){
	MFExpressionStatement *statement = [[MFExpressionStatement alloc] init];
	statement.kind = MFStatementKindExpression;
	statement.expr = expr;
	return statement;
}


MFElseIf *mf_create_else_if(YTXMFExpression *condition, YTXMFBlockBody *thenBlock){
	MFElseIf *elseIf = [[MFElseIf alloc] init];
	elseIf.condition = condition;
	elseIf.thenBlock = thenBlock;
	return elseIf;
}


MFIfStatement *mf_create_if_statement(YTXMFExpression *condition,YTXMFBlockBody *thenBlock,NSArray<MFElseIf *> *elseIfList,YTXMFBlockBody *elseBlocl){
	MFIfStatement *statement = [[MFIfStatement alloc] init];
	statement.kind = MFStatementKindIf;
	statement.condition = condition;
	statement.thenBlock = thenBlock;
	statement.elseBlocl = elseBlocl;
	statement.elseIfList = elseIfList;
	return statement;
}


MFCase *mf_create_case(YTXMFExpression *expr, YTXMFBlockBody *block){
	MFCase *case_ = [[MFCase alloc] init];
	case_.expr = expr;
	case_.block = block;
	return case_;
}


MFSwitchStatement *mf_create_switch_statement(YTXMFExpression *expr, NSArray<MFCase *> *caseList, YTXMFBlockBody *defaultBlock){
	MFSwitchStatement *statement = [[MFSwitchStatement alloc] init];
	statement.kind = MFStatementKindSwitch;
	statement.expr = expr;
	statement.caseList = caseList;
	statement.defaultBlock = defaultBlock;
	return statement;
}


MFForStatement *mf_create_for_statement(YTXMFExpression *initializerExpr, YTXMFDeclaration *declaration,
										  YTXMFExpression *condition, YTXMFExpression *post, YTXMFBlockBody *block){
	MFForStatement *statement = [[MFForStatement alloc] init];
	statement.kind = MFStatementKindFor;
	statement.initializerExpr = initializerExpr;
	statement.declaration = declaration;
	statement.condition = condition;
	statement.post = post;
	statement.block = block;
	return statement;
}


MFForEachStatement *mf_create_for_each_statement(YTXMFTypeSpecifier *typeSpecifier,NSString *varName, YTXMFExpression *arrayExpr,YTXMFBlockBody *block){
	MFForEachStatement *statement = [[MFForEachStatement alloc] init];
	statement.kind = MFStatementKindForEach;
	if (typeSpecifier) {
		statement.declaration = mf_create_declaration(MFDeclarationModifierNone,typeSpecifier, varName, nil);
	}else{
		MFIdentifierExpression *varExpr = (MFIdentifierExpression *)mf_create_expression(MF_IDENTIFIER_EXPRESSION);
		varExpr.identifier = varName;
		statement.identifierExpr = varExpr;
	}
	statement.collectionExpr = arrayExpr;
	statement.block = block;
	return statement;
}


MFWhileStatement *mf_create_while_statement(YTXMFExpression *condition, YTXMFBlockBody *block){
	MFWhileStatement *statement = [[MFWhileStatement alloc] init];
	statement.kind = MFStatementKindWhile;
	statement.condition = condition;
	statement.block = block;
	return statement;
}


MFDoWhileStatement *mf_create_do_while_statement(YTXMFBlockBody *block, YTXMFExpression *condition){
	MFDoWhileStatement *statement = [[MFDoWhileStatement alloc] init];
	statement.kind = MFStatementKindDoWhile;
	statement.block = block;
	statement.condition = condition;
	return statement;
}


MFContinueStatement *mf_create_continue_statement(){
	MFContinueStatement *statement = [[MFContinueStatement alloc] init];
	statement.kind = MFStatementKindContinue;
	return statement;
}


MFBreakStatement *mf_create_break_statement(){
	MFBreakStatement *statement = [[MFBreakStatement alloc] init];
	statement.kind = MFStatementKindBreak;
	return statement;
	
}


MFReturnStatement *mf_create_return_statement(YTXMFExpression *retValExpr){
	MFReturnStatement *statement = [[MFReturnStatement alloc] init];
	statement.kind = MFStatementKindReturn;
	statement.retValExpr = retValExpr;
	return statement;
}


YTXMFBlockBody *mf_open_block_statement(){
	YTXMFBlockBody *block = [[YTXMFBlockBody alloc] init];
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	block.outBlock = interpreter.currentBlock;
	interpreter.currentBlock = block;
	return block;
}


YTXMFBlockBody *mf_close_block_statement(YTXMFBlockBody *block, NSArray<YTXMFStatement *> *statementList){
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	NSCAssert(block == interpreter.currentBlock, @"block != mf_get_current_compile_util().currentBlock");
	interpreter.currentBlock = block.outBlock;
	block.statementList = statementList;
	return block;
}


YTXMFStructDeclare *mf_create_struct_declare(YTXMFExpression *annotaionIfConditionExpr, NSString *structName, NSString *typeEncodingKey, YTXMFExpression *typeEncodingValueExpr, NSString *keysKey, NSArray<NSString *> *keysValue){
	if (![typeEncodingKey isEqualToString:@"typeEncoding"]) {
        mf_throw_error(mf_get_current_compile_util().currentLineNumber, MFSemanticErrorStructDeclareLackFieldEncoding, @"struct: %@ declare lack field typeEncoding",structName);
        return nil;
	}
	if (![keysKey isEqualToString:@"keys"]) {
        mf_throw_error(mf_get_current_compile_util().currentLineNumber, MFSemanticErrorStructDeclareLackFieldKeys, @"struct: %@ declare lack field Keys",structName);
        return nil;
	}
    const char *typeEncodingValue = typeEncodingValueExpr.cstringValue;
	YTXMFStructDeclare *structDeclare = [[YTXMFStructDeclare alloc] init];
	structDeclare.annotationIfConditionExpr = annotaionIfConditionExpr;
	structDeclare.name = structName;
	structDeclare.typeEncoding = typeEncodingValue;
	structDeclare.keys = keysValue;
	return structDeclare;
}

YTXMFTypeSpecifier *mf_create_cfuntion_type_specifier( NSArray<NSString *> *typeList){
    YTXMFTypeSpecifier *typeSpecifier = [[YTXMFTypeSpecifier alloc] init];
    typeSpecifier.typeKind = MF_TYPE_C_FUNCTION;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dic = @{@"void"         : @"v",
                @"BOOL"         : @"B",
                @"int"          : @"i",
                @"long"         : @"l",
                @"int8_t"       : @"c",
                @"int16_t"      : @"s",
                @"int32_t"      : @"i",
                @"int64_t"      : @"q",
                @"u_int"        : @"I",
                @"u_long"       : @"L",
                @"u_int8_t"     : @"C",
                @"u_int16_t"    : @"S",
                @"u_int32_t"    : @"I",
                @"u_int64_t"    : @"Q",
#if defined(__LP64__) && __LP64__
                @"size_t"       : @"Q",
#else
                @"size_t"       : @"I",
#endif
#if defined(__LP64__) && __LP64__
                @"CGFloat"      : @"d",
#else
                @"CGFloat"     : @"f",
#endif
                @"float"        : @"f",
                @"double"       : @"d",
                @"char *"       : @"*",
                @"void *"       : @"^v",
                @"id"           : @"@",
                @"SEL"          : @":",
                @"Class"        : @"#",
                };
    });
    NSMutableArray *typeListEncode  = [NSMutableArray arrayWithCapacity:typeList.count];
    int j = 0;
    for (int i = 0; i < typeList.count; i++) {
        NSString *typeName = typeList[i];
        if (i != 0 && [typeName isEqualToString:@"void"]) {
            continue;
        }
        NSString *typeEncode = nil;
        if ([typeName hasPrefix:@"struct "]) {
            YTXMFStructDeclareTable *structDeclareTable = [YTXMFStructDeclareTable shareInstance];
            NSString *structName = [typeName substringFromIndex:7];
            YTXMFStructDeclare *structDeclare = [structDeclareTable getStructDeclareWithName:structName];
            if (!structDeclare) {
                mf_throw_error(mf_get_current_compile_util().currentLineNumber, MFSemanticErrorStructNoDeclare, @"struct: %@ no declare", structName);
                return nil;
            }
            typeEncode = @(structDeclare.typeEncoding);
        }else{
            typeEncode = dic[typeName];
            if (!typeEncode) {
                mf_throw_error(mf_get_current_compile_util().currentLineNumber, MFSemanticErrorNotSupportCFunctionTypeDeclare, @"not support CFunction type: %@",typeName);
                return nil;
            }
        }
        typeListEncode[j] = typeEncode;
        j++;
    }
    NSString *returnTypeEncode = typeListEncode[0];
    NSArray *paramListTypeEncode = [typeListEncode subarrayWithRange:NSMakeRange(1, typeListEncode.count - 1)];
    typeSpecifier.returnTypeEncode = returnTypeEncode;
    typeSpecifier.paramListTypeEncode = paramListTypeEncode;
    
    return typeSpecifier;
}


YTXMFTypeSpecifier *mf_create_type_specifier(MFTypeSpecifierKind kind){
	YTXMFTypeSpecifier *typeSpecifier = [[YTXMFTypeSpecifier alloc] init];
	typeSpecifier.typeKind = kind;
	return typeSpecifier;
}


YTXMFTypeSpecifier *mf_create_struct_type_specifier(NSString *structName){
	YTXMFTypeSpecifier *typeSpecifier = mf_create_type_specifier(MF_TYPE_STRUCT);
	typeSpecifier.structName = structName;
	return typeSpecifier;
}


MFParameter *mf_create_parameter(YTXMFTypeSpecifier *type, NSString *name){
	MFParameter *parameter = [[MFParameter alloc] init];
	parameter.type = type;
	parameter.name = name;
	parameter.lineNumber = mf_get_current_compile_util().currentLineNumber;
	return parameter;
}


YTXMFFunctionDefinition *mf_create_function_definition(YTXMFTypeSpecifier *returnTypeSpecifier,NSString *name ,NSArray<MFParameter *> *prasms, YTXMFBlockBody *block){
	YTXMFFunctionDefinition *functionDefinition = [[YTXMFFunctionDefinition alloc] init];
	functionDefinition.returnTypeSpecifier = returnTypeSpecifier;
	functionDefinition.name = name;
	functionDefinition.params = prasms;
	functionDefinition.block = block;
	return functionDefinition;
}


MFMethodNameItem *mf_create_method_name_item(NSString *name, YTXMFTypeSpecifier *typeSpecifier, NSString *paramName){
	MFMethodNameItem *item = [[MFMethodNameItem alloc] init];
	item.name = name;
	if (typeSpecifier && paramName) {
		MFParameter *param = [[MFParameter alloc] init];
		param.type = typeSpecifier;
		param.name = paramName;
		item.param = param;
	}
	return item;
}


MFMethodDefinition *mf_create_method_definition(YTXMFExpression *annotaionIfConditionExpr, BOOL classMethod, YTXMFTypeSpecifier *returnTypeSpecifier, NSArray<MFMethodNameItem *> *items, YTXMFBlockBody *block){
	MFMethodDefinition *methodDefinition = [[MFMethodDefinition alloc] init];
	methodDefinition.annotationIfConditionExpr = annotaionIfConditionExpr;
	methodDefinition.classMethod = classMethod;
	YTXMFFunctionDefinition *funcDefinition = [[YTXMFFunctionDefinition alloc] init];
	funcDefinition.kind = MFFunctionDefinitionKindMethod;
	funcDefinition.returnTypeSpecifier = returnTypeSpecifier;
	NSMutableArray<MFParameter *> *params = [NSMutableArray array];
	MFParameter *selfParam = [[MFParameter alloc] init];
	selfParam.type = mf_create_type_specifier(MF_TYPE_OBJECT);
	selfParam.name = @"self";
    
	MFParameter *selParam = [[MFParameter alloc] init];
	selParam.type = mf_create_type_specifier(MF_TYPE_SEL);
	selParam.name = @"_cmd";
	
	[params addObject:selfParam];
	[params addObject:selParam];
	
	NSMutableString *selector = [NSMutableString string];
	for (MFMethodNameItem *itme in items) {
		[selector appendString:itme.name];
		if (itme.param) {
			[params addObject:itme.param];
		}
		
	}
	funcDefinition.name = selector;
	funcDefinition.params = params;
	funcDefinition.block = block;
	methodDefinition.functionDefinition = funcDefinition;
	return methodDefinition;
}


MFPropertyDefinition *mf_create_property_definition(YTXMFExpression *annotaionIfConditionExpr, MFPropertyModifier modifier, YTXMFTypeSpecifier *typeSpecifier, NSString *name){
	MFPropertyDefinition *propertyDefinition = [[MFPropertyDefinition alloc] init];
	propertyDefinition.annotationIfConditionExpr = annotaionIfConditionExpr;
	propertyDefinition.lineNumber = mf_get_current_compile_util().currentLineNumber;
	propertyDefinition.modifier = modifier;
	propertyDefinition.typeSpecifier = typeSpecifier;
	propertyDefinition.name = name;
	return propertyDefinition;
}


void mf_start_class_definition(YTXMFExpression *annotaionIfConditionExpr, NSString *name, NSString *superNmae, NSArray<NSString *> *protocolNames){
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	YTXMFClassDefinition *classDefinition = [[YTXMFClassDefinition alloc] init];
	classDefinition.lineNumber = interpreter.currentLineNumber;
	classDefinition.annotationIfConditionExpr = annotaionIfConditionExpr;
	classDefinition.name = name;
	classDefinition.superNmae = superNmae;
	classDefinition.protocolNames = protocolNames;
	interpreter.currentClassDefinition = classDefinition;
}


YTXMFClassDefinition *mf_end_class_definition(NSArray<MFMemberDefinition *> *members){
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	YTXMFClassDefinition *classDefinition = interpreter.currentClassDefinition;
	NSMutableArray<MFPropertyDefinition *> *propertyDefinition = [NSMutableArray array];
	NSMutableArray<MFMethodDefinition *> *classMethods = [NSMutableArray array];
	NSMutableArray<MFMethodDefinition *> *instanceMethods = [NSMutableArray array];
	for (MFMemberDefinition *memberDefinition in members) {
		memberDefinition.classDefinition = classDefinition;
		if ([memberDefinition isKindOfClass:[MFPropertyDefinition class]]) {
			[propertyDefinition addObject:(MFPropertyDefinition *)memberDefinition];
		}else if ([memberDefinition isKindOfClass:[MFMethodDefinition class]]){
			MFMethodDefinition *methodDefinition = (MFMethodDefinition *)memberDefinition;
			if (methodDefinition.classMethod) {
				[classMethods addObject:methodDefinition];
			}else{
				[instanceMethods addObject:methodDefinition];
			}
		}
	}
	classDefinition.properties = propertyDefinition;
	classDefinition.classMethods = classMethods;
	classDefinition.instanceMethods = instanceMethods;
	interpreter.currentClassDefinition = nil;
	return classDefinition;
}


void mf_add_struct_declare(YTXMFStructDeclare *structDeclare){
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	interpreter.structDeclareDic[structDeclare.name] = structDeclare;
	[interpreter.topList addObject:structDeclare];
}


void mf_add_class_definition(YTXMFClassDefinition *classDefinition){
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	interpreter.classDefinitionDic[classDefinition.name] = classDefinition;
	[interpreter.topList addObject:classDefinition];
}


void mf_add_statement(YTXMFStatement *statement){
	YTXMFInterpreter *interpreter = mf_get_current_compile_util();
	[interpreter.topList addObject:statement];
}

void mf_add_typedef(MFTypeSpecifierKind type, NSString *alias){
    YTXMFTypedefTable *typedefTable = [YTXMFTypedefTable shareInstance];
    [typedefTable typedefType:type identifer:alias];
}

void mf_add_typedef_from_alias(NSString *alias_existing, NSString *alias_new){
    YTXMFTypedefTable *typedefTable = [YTXMFTypedefTable shareInstance];
    MFTypeSpecifierKind type = [typedefTable typeWtihIdentifer:alias_existing];
    if (type == MF_TYPE_UNKNOWN) {
        mf_throw_error(mf_get_current_compile_util().currentLineNumber, MFSemanticErrorTypedefWithUnknownExistingType, @"typedef error, unknown type: %@", alias_existing);
    }
    mf_add_typedef(type, alias_new);
}












