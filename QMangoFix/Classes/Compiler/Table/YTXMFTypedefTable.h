//
//  MFTypedefTable.h
//  MangoFix
//
//  Created by yongpengliang on 2019/6/14.
//  Copyright © 2019 yongpengliang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YTXMFTypeSpecifier.h"

NS_ASSUME_NONNULL_BEGIN

@interface YTXMFTypedefTable : NSObject

+ (instancetype)shareInstance;

- (void)typedefType:(MFTypeSpecifierKind)type identifer:(NSString *)identifer;
- (MFTypeSpecifierKind)typeWtihIdentifer:(NSString *)identifer;

@end

NS_ASSUME_NONNULL_END
