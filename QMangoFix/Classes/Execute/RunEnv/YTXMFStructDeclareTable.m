//
//  MFStructDeclareTable.m
//  MangoFix
//
//  Created by jerry.yong on 2018/2/24.
//  Copyright © 2018年 yongpengliang. All rights reserved.
//

#import "YTXMFStructDeclareTable.h"

@implementation YTXMFStructDeclareTable{
	NSMutableDictionary<NSString *, YTXMFStructDeclare *> *_dic;
    NSLock *_lock;
}

- (instancetype)init{
	if (self = [super init]) {
		_dic = [NSMutableDictionary dictionary];
        _lock = [[NSLock alloc] init];
	}
	return self;
}
+ (instancetype)shareInstance{
	static id st_instance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		st_instance = [[YTXMFStructDeclareTable alloc] init];
	});
	return st_instance;
}

- (void)addStructDeclare:(YTXMFStructDeclare *)structDeclare{
    [_lock lock];
	_dic[structDeclare.name] = structDeclare;
    [_lock unlock];
}

- (YTXMFStructDeclare *)getStructDeclareWithName:(NSString *)name{
    [_lock lock];
	YTXMFStructDeclare *declare = _dic[name];
    [_lock unlock];
    return declare;
}
@end
