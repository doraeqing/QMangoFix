//
//  MFContext.m
//  MangoFix
//
//  Created by jerry.yong on 2017/12/25.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import "YTXMFContext.h"
#import "create.h"
#import "execute.h"
#import "YTXMFRSA.h"

@interface YTXMFContext()
@property(nonatomic, strong) YTXMFInterpreter *interpreter;
@property(nonatomic, copy) NSString *privateKey;
@end

@implementation YTXMFContext

- (instancetype)initWithRSAPrivateKey:(NSString *)privateKey{
    if (self = [super init]) {
        _interpreter = [[YTXMFInterpreter alloc] init];
        _privateKey = privateKey;
    }
    return self;
}

- (void)evalMangoScriptWithURL:(NSURL *)url{
    @autoreleasepool {
        NSError *error;
        NSString *rsaEncryptedBase64String = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"MangoFix: %@",error);
            return;
        }
        [self evalMangoScriptWithRSAEncryptedBase64String:rsaEncryptedBase64String];
        
    }
}

- (void)evalMangoScriptWithRSAEncryptedBase64String:(NSString *)rsaEncryptedBase64String{
    @autoreleasepool {
        NSString *mangoFixString = [YTXMFRSA decryptString:rsaEncryptedBase64String privateKey:self.privateKey];
        if (!mangoFixString.length) {
            NSLog(@"MangoFix: RSA decrypt error!");
            return;
        }
        mf_set_current_compile_util(self.interpreter);
        mf_add_built_in(self.interpreter);
        [self.interpreter compileSourceWithString:mangoFixString];
        mf_set_current_compile_util(nil);
        mf_interpret(self.interpreter);
    }
}

- (YTXMFValue *)objectForKeyedSubscript:(id)key{
	return [_interpreter.topScope getValueWithIdentifier:key];
}

- (void)setObject:(YTXMFValue *)value forKeyedSubscript:(NSString *)key{
    if (!value) {
        return;
    }
	[_interpreter.topScope setValue:value withIndentifier:key];
}


#ifdef DEBUG
- (void)evalMangoScriptWithDebugURL:(NSURL *)url{
    @autoreleasepool {
        NSError *error;
        NSString *mangoFixString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        mf_set_current_compile_util(self.interpreter);
        mf_add_built_in(self.interpreter);
        [self.interpreter compileSourceWithString:mangoFixString];
        mf_set_current_compile_util(nil);
        mf_interpret(self.interpreter);
    }
}
#endif

@end
