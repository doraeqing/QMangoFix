//
//  create.h
//  MangoFix
//
//  Created by jerry.yong on 2018/2/28.
//  Copyright © 2018年 yongpengliang. All rights reserved.
//

#ifndef create_h
#define create_h
#import "mf_ast.h"

void mf_open_string_literal_buf(void);

void mf_append_string_literal(int letter);

const char* mf_end_string_literal(void);

NSString *mf_create_identifier(char *str);

MFStructEntry *mf_create_struct_entry(NSString *key, YTXMFExpression *valueExpr);

MFDicEntry *mf_create_dic_entry(YTXMFExpression *keyExpr, YTXMFExpression *valueExpr);

YTXMFExpression *mf_create_expression(MFExpressionKind kind);

void mf_build_block_expr(MFBlockExpression *expr, YTXMFTypeSpecifier *returnTypeSpecifier, NSArray<MFParameter *> *params,  YTXMFBlockBody *block);

YTXMFStructDeclare *mf_create_struct_declare(YTXMFExpression *annotaionIfConditionExpr, NSString *structName, NSString *typeEncodingKey, YTXMFExpression *typeEncodingValueExpr, NSString *keysKey, NSArray<NSString *> *keysValue);

YTXMFTypeSpecifier *mf_create_type_specifier(MFTypeSpecifierKind kind);

YTXMFTypeSpecifier *mf_create_cfuntion_type_specifier( NSArray<NSString *> *typeList);

YTXMFTypeSpecifier *mf_create_struct_type_specifier(NSString *structName);

MFParameter *mf_create_parameter(YTXMFTypeSpecifier *type, NSString *name);

YTXMFDeclaration *mf_create_declaration(MFDeclarationModifier modifier_list, YTXMFTypeSpecifier *type, NSString *name, YTXMFExpression *initializer);

MFDeclarationStatement *mf_create_declaration_statement(YTXMFDeclaration *declaration);

MFExpressionStatement *mf_create_expression_statement(YTXMFExpression *expr);

MFElseIf *mf_create_else_if(YTXMFExpression *condition,  YTXMFBlockBody *thenBlock);

MFIfStatement *mf_create_if_statement(YTXMFExpression *condition, YTXMFBlockBody *thenBlock,NSArray<MFElseIf *> *elseIfList, YTXMFBlockBody *elseBlocl);

MFCase *mf_create_case(YTXMFExpression *expr,  YTXMFBlockBody *block);

MFSwitchStatement *mf_create_switch_statement(YTXMFExpression *expr, NSArray<MFCase *> *caseList,  YTXMFBlockBody *defaultBlock);

MFForStatement *mf_create_for_statement(YTXMFExpression *initializerExpr, YTXMFDeclaration *declaration,
										  YTXMFExpression *condition, YTXMFExpression *post,  YTXMFBlockBody *block);

MFForEachStatement *mf_create_for_each_statement( YTXMFTypeSpecifier *typeSpecifier, NSString *varName, YTXMFExpression *arrayExpr,  YTXMFBlockBody *block);

MFWhileStatement *mf_create_while_statement(YTXMFExpression *condition,  YTXMFBlockBody *block);

MFDoWhileStatement *mf_create_do_while_statement(  YTXMFBlockBody *block, YTXMFExpression *condition);

MFContinueStatement *mf_create_continue_statement(void);

MFBreakStatement *mf_create_break_statement(void);

MFReturnStatement *mf_create_return_statement(YTXMFExpression *retValExpr);

 YTXMFBlockBody *mf_open_block_statement(void);

 YTXMFBlockBody *mf_close_block_statement( YTXMFBlockBody *block, NSArray<YTXMFStatement *> *statementList);

void mf_start_class_definition(YTXMFExpression *annotaionIfConditionExpr, NSString *name, NSString *superNmae, NSArray<NSString *> *protocolNames);

YTXMFClassDefinition *mf_end_class_definition(NSArray<MFMemberDefinition *> *members);

YTXMFFunctionDefinition *mf_create_function_definition(YTXMFTypeSpecifier *returnTypeSpecifier,NSString *name ,NSArray<MFParameter *> *prasms,  YTXMFBlockBody *block);

MFMethodNameItem *mf_create_method_name_item(NSString *name, YTXMFTypeSpecifier *typeSpecifier, NSString *paramName);

MFMethodDefinition *mf_create_method_definition(YTXMFExpression *annotaionIfConditionExpr, BOOL classMethod, YTXMFTypeSpecifier *returnTypeSpecifier, NSArray<MFMethodNameItem *> *items,  YTXMFBlockBody *block);

MFPropertyDefinition *mf_create_property_definition(YTXMFExpression *annotaionIfConditionExpr, MFPropertyModifier modifier, YTXMFTypeSpecifier *typeSpecifier, NSString *name);

void mf_add_class_definition(YTXMFClassDefinition *classDefinition);

void mf_add_struct_declare(YTXMFStructDeclare *structDeclare);

void mf_add_statement(YTXMFStatement *statement);

void mf_add_typedef(MFTypeSpecifierKind type, NSString *alias);

void mf_add_typedef_from_alias(NSString *alias_existing, NSString *alias_new);

YTXMFInterpreter *mf_get_current_compile_util(void);

void mf_set_current_compile_util(YTXMFInterpreter *interpreter);

#endif /* create_h */
