//
//  MFVarDeclareChain.m
//  MangoFix
//
//  Created by yongpengliang on 2019/5/1.
//  Copyright © 2019 yongpengliang. All rights reserved.
//

#import "YTXMFVarDeclareChain.h"

@implementation YTXMFVarDeclareChain{
    NSMutableArray *_indentiferArr;
}

- (instancetype)init{
    if (self = [super init]) {
        _indentiferArr = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)varDeclareChainWithNext:(YTXMFVarDeclareChain *)next{
    YTXMFVarDeclareChain *chain = [[YTXMFVarDeclareChain alloc] init];
    chain.next = next;
    return chain;
}

- (BOOL)isInThisNote:(NSString *)indentifer{
    return [_indentiferArr indexOfObject:indentifer] != NSNotFound;
}

- (BOOL)isInChain:(NSString *)indentifer{
    YTXMFVarDeclareChain *chain = self;
    while (chain) {
        if ([chain isInThisNote:indentifer]) {
            return YES;
        }
        chain = chain.next;
    }
    return NO;
}

- (void)addIndentifer:(NSString *)indentifer{
    if (!indentifer.length) {
        return;
    }
    [_indentiferArr addObject:indentifer];
}

@end
