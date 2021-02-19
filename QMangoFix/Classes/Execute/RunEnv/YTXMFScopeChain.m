//
//  ANEScopeChain.m
//  MangoFix
//
//  Created by jerry.yong on 2018/2/28.
//  Copyright © 2018年 yongpengliang. All rights reserved.
//

#import <objc/runtime.h>
#import "YTXMFScopeChain.h"
#import "YTXMFValue.h"
#import "YTXMFBlock.h"
#import "YTXMFValue+Private.h"
#import "YTXMFPropertyMapTable.h"
#import "YTXMFWeakPropertyBox.h"
#import "util.h"
@interface YTXMFScopeChain()
@property (strong, nonatomic) NSMutableDictionary<NSString *,YTXMFValue *> *vars;
@property (strong,nonatomic)NSLock *lock;
@end

@implementation YTXMFScopeChain

+ (instancetype)scopeChainWithNext:(YTXMFScopeChain *)next{
	YTXMFScopeChain *scope = [YTXMFScopeChain new];
	scope.next = next;
	return scope;
}

- (instancetype)init{
	if (self = [super init]) {
		_vars = [NSMutableDictionary dictionary];
        _lock = [[NSLock alloc] init];
	}
	return self;
}


- (void)setValue:(YTXMFValue *)value withIndentifier:(NSString *)identier{
    [self.lock lock];
    self.vars[identier] = value;
    [self.lock unlock];
}

- (YTXMFValue *)getValueWithIdentifier:(NSString *)identifer{
    [self.lock lock];
	YTXMFValue *value = self.vars[identifer];
    [self.lock unlock];
	return value;
}

extern const void *mf_propKey(NSString *propName);

- (NSString *)propNameByIvarName:(NSString *)ivarName{
    if (ivarName.length < 2) {
        return nil;
    }
    
    if (![ivarName hasPrefix:@"_"]) {
        return nil;
    }
    
    return [ivarName substringFromIndex:1];
}

- (void)assignWithIdentifer:(NSString *)identifier value:(YTXMFValue *)value{
	for (YTXMFScopeChain *pos = self; pos; pos = pos.next) {
		if (pos.instance) {
            NSString *propName = [self propNameByIvarName:identifier];
            YTXMFPropertyMapTable *table = [YTXMFPropertyMapTable shareInstance];
            Class clazz = object_getClass(pos.instance);
            MFPropertyDefinition *propDef = [table getPropertyMapTableItemWith:clazz name:propName].property;
            Ivar ivar;
            if (propDef) {
                id associationValue = value;
                const char *type = [propDef.typeSpecifier typeEncoding];
                if (*type == '@') {
                    associationValue = [value objectValue];
                }
                MFPropertyModifier modifier = propDef.modifier;
                if ((modifier & MFPropertyModifierMemMask) == MFPropertyModifierMemWeak) {
                    associationValue = [[YTXMFWeakPropertyBox alloc] initWithTarget:value];
                }
                objc_AssociationPolicy associationPolicy = mf_AssociationPolicy_with_PropertyModifier(modifier);
                objc_setAssociatedObject(pos.instance, mf_propKey(propName), associationValue, associationPolicy);
            }else if((ivar = class_getInstanceVariable(object_getClass(pos.instance),identifier.UTF8String))){
                const char *ivarEncoding = ivar_getTypeEncoding(ivar);
                if (*ivarEncoding == '@') {
                    object_setIvar(pos.instance, ivar, [value c2objectValue]);
                }else{
                    void *ptr = (__bridge void *)(pos.instance) +  ivar_getOffset(ivar);
                    [value assignToCValuePointer:ptr typeEncoding:ivarEncoding];
                }
                return;
                
            }
		}else{
			YTXMFValue *srcValue = [pos getValueWithIdentifier:identifier];
			if (srcValue) {
				[srcValue assignFrom:value];
				return;
			}
		}
		
	}
}

- (YTXMFValue *)getValueWithIdentifier:(NSString *)identifier endScope:(YTXMFScopeChain *)endScope{
    for (YTXMFScopeChain *pos = self; pos != endScope; pos = pos.next) {
        if (pos.instance) {
            NSString *propName = [self propNameByIvarName:identifier];
            YTXMFPropertyMapTable *table = [YTXMFPropertyMapTable shareInstance];
            Class clazz = object_getClass(pos.instance);
            MFPropertyDefinition *propDef = [table getPropertyMapTableItemWith:clazz name:propName].property;
            Ivar ivar;
            if (propDef) {
                id propValue = objc_getAssociatedObject(pos.instance, mf_propKey(propName));
                const char *type = [propDef.typeSpecifier typeEncoding];
                YTXMFValue *value = propValue;
                if (!propValue) {
                    value = [YTXMFValue defaultValueWithTypeEncoding:type];
                }else if(*type == '@'){
                    if ([propValue isKindOfClass:[YTXMFWeakPropertyBox class]]) {
                        YTXMFWeakPropertyBox *box = propValue;
                        value = [YTXMFValue valueInstanceWithObject:box.target];
                    }else{
                        value = [YTXMFValue valueInstanceWithObject:propValue];
                    }
                }
                return value;
                
            }else if((ivar = class_getInstanceVariable(object_getClass(pos.instance),identifier.UTF8String))){
                YTXMFValue *value;
                const char *ivarEncoding = ivar_getTypeEncoding(ivar);
                if (*ivarEncoding == '@') {
                    id ivarValue = object_getIvar(pos.instance, ivar);
                    value = [YTXMFValue valueInstanceWithObject:ivarValue];
                }else{
                    void *ptr = (__bridge void *)(pos.instance) +  ivar_getOffset(ivar);
                    value = [[YTXMFValue alloc] initWithCValuePointer:ptr typeEncoding:ivarEncoding bridgeTransfer:NO];
                }
                return value;
                
            }
        }else{
            YTXMFValue *value = [pos getValueWithIdentifier:identifier];
            if (value) {
                return value;
            }
            
        }
    }
    return nil;
}

- (YTXMFValue *)getValueWithIdentifierInChain:(NSString *)identifier{
    return [self getValueWithIdentifier:identifier endScope:nil];
}

- (void)setMangoBlockVarNil{
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        [self.lock lock];
//        NSArray *allValues = [self.vars allValues];
//        for (MFValue *value in allValues) {
//            if ([value isObject]) {
//                Class ocBlockClass = NSClassFromString(@"NSBlock");
//                if ([[value c2objectValue] isKindOfClass:ocBlockClass]) {
//                    struct MFSimulateBlock *blockStructPtr = (__bridge void *)value.objectValue;
//                    if (blockStructPtr->flags & BLOCK_CREATED_FROM_MFGO) {
//                        value.objectValue = nil;
//                    }
//                }
//
//            }
//        }
//        [self.lock unlock];
//    });
    
}

@end

