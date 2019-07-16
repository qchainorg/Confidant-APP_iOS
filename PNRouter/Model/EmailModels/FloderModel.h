//
//  FloderModel.h
//  PNRouter
//
//  Created by 旷自辉 on 2019/7/10.
//  Copyright © 2019 旷自辉. All rights reserved.
//

#import "BBaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface FloderModel : BBaseModel
@property (nonatomic , strong) NSString *path;
@property (nonatomic , strong) NSString *name;
@property (nonatomic , assign) int count;
@end

NS_ASSUME_NONNULL_END
