//
//  ANEStatementResult.m
//  MangoFix
//
//  Created by jerry.yong on 2018/2/28.
//  Copyright © 2018年 yongpengliang. All rights reserved.
//

#import "YTXMFStatementResult.h"


@implementation YTXMFStatementResult

+ (instancetype)normalResult{
	YTXMFStatementResult *res = [YTXMFStatementResult new];
	res.type = MFStatementResultTypeNormal;
	return res;
}

+ (instancetype)returnResult{
	YTXMFStatementResult *res = [YTXMFStatementResult new];
	res.type = MFStatementResultTypeReturn;
	return res;
}

+ (instancetype)breakResult{
	YTXMFStatementResult *res = [YTXMFStatementResult new];
	res.type = MFStatementResultTypeBreak;
	return res;
}

+ (instancetype)continueResult{
	YTXMFStatementResult *res = [YTXMFStatementResult new];
	res.type = MFStatementResultTypeContinue;
	return res;
}

@end

