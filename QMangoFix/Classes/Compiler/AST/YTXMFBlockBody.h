//
//  MFBlock.h
//  MangoFix
//
//  Created by jerry.yong on 2017/11/28.
//  Copyright © 2017年 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFStatement.h"


@interface YTXMFBlockBody: NSObject

@property (strong, nonatomic) NSArray<YTXMFStatement *> *statementList;
//@property (strong, nonatomic) NSMutableArray<MFDeclaration *> *declarations;
@property (weak, nonatomic) YTXMFBlockBody *outBlock;

@end
