//
//  PNSearchViewController.h
//  PNRouter
//
//  Created by 旷自辉 on 2019/8/8.
//  Copyright © 2019 旷自辉. All rights reserved.
//

#import "PNBaseViewController.h"
@class FloderModel;

NS_ASSUME_NONNULL_BEGIN

typedef void(^ClickObjectBlock)(id object);

@interface PNSearchViewController : PNBaseViewController
@property (nonatomic ,copy) ClickObjectBlock clickObjBlock;
- (instancetype)initWithData:(NSMutableArray *) dataArr isMessage:(BOOL) isM floder:(FloderModel *) fm;
@end

NS_ASSUME_NONNULL_END
