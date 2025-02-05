//
//  ChatListDataUtil.m
//  PNRouter
//
//  Created by 旷自辉 on 2018/9/15.
//  Copyright © 2018年 旷自辉. All rights reserved.
//

#import "ChatListDataUtil.h"
#import "ChatListModel.h"
#import "FriendModel.h"
#import "NSString+Base64.h"
#import "SystemUtil.h"
#import "UserConfig.h"

@implementation ChatListDataUtil
+ (instancetype) getShareObject
{
    static ChatListDataUtil *shareObject = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareObject = [[self alloc] init];
        shareObject.dataArray = [NSMutableArray array];
        shareObject.groupArray = [NSMutableArray array];
        shareObject.friendArray = [NSMutableArray array];
        if (![SystemUtil isSocketConnect]) {
            shareObject.fileParames = [NSMutableDictionary dictionary];
            shareObject.fileNameParames = [NSMutableDictionary dictionary];
            shareObject.pullTimerDic = [NSMutableDictionary dictionary];
            shareObject.fileCancelParames = [NSMutableDictionary dictionary];
            shareObject.fileNumberParames = [NSMutableDictionary dictionary];
        }
       
    });
    return shareObject;
}

- (NSString *) getFriendSignPublickeyWithFriendid:(NSString *) fid
{
    __block NSString *signPublicKey = @"";
    [[ChatListDataUtil getShareObject].friendArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        FriendModel *friendModel = (FriendModel *)obj;
        if ([friendModel.userId isEqualToString:fid]) {
            signPublicKey = friendModel.signPublicKey;
            *stop = YES;
        }
    }];
    return signPublicKey;
}

- (FriendModel *) getFriendWithUserid:(NSString *) fid
{
    __block FriendModel *model = nil;
    [[ChatListDataUtil getShareObject].friendArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        FriendModel *friendModel = (FriendModel *)obj;
        if ([friendModel.userId isEqualToString:fid]) {
            model = friendModel;
            *stop = YES;
        }
    }];
    return model;
}

- (NSString *) getFriendUserKeyWithEmailAddress:(NSString *) email
{
    __block NSString *userKey = @"";
    [[ChatListDataUtil getShareObject].friendArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        FriendModel *friendModel = (FriendModel *)obj;
        if (friendModel.Mails) {
            NSArray *mails = [friendModel.Mails componentsSeparatedByString:@","]?:@[];
            if ([mails containsObject:email]) {
                userKey = friendModel.signPublicKey;
                *stop = YES;
            }
        }
    }];
    return userKey;
}

- (void) addFriendModel:(ChatListModel *) model
{
    @synchronized (self) {
        // 加锁操作
        // 在好友列表中遍历赋值
        if (model.isGroup) {
            NSArray *friends = [ChatListModel bg_find:FRIEND_CHAT_TABNAME where:[NSString stringWithFormat:@"where %@=%@ and %@=%@ and %@=%@",bg_sqlKey(@"groupID"),bg_sqlValue(model.groupID),bg_sqlKey(@"myID"),bg_sqlValue(model.myID),bg_sqlKey(@"isGroup"),bg_sqlValue(@(1))]];
            if (friends && friends.count > 0) {
                ChatListModel *model1 = friends[0];
                model1.friendName = model.friendName?:@"";
                model1.groupName = model.groupName;
                model1.groupAlias = model.groupAlias;
                model1.atIds = model.atIds;
                model1.atNames = model.atNames;
                if (model1.isATYou) {
                    if (model.isOwerClearAtYour) {
                        model1.isATYou = NO;
                    }
                } else {
                    if (model.isATYou) {
                        model1.isATYou = YES;
                    }
                }
               
                model1.isAT = model.isAT;
                model1.isHD = model.isHD;
                model1.unReadNum = model.isHD?@([model1.unReadNum integerValue] + 1):model1.unReadNum;
                model1.isDraft = model.isDraft;
                if (!model1.isDraft) {
                    model1.lastMessage = model.lastMessage;
                    model1.chatTime = model.chatTime;
                }
                model1.draftMessage = model.draftMessage;
                model1.routerName = model.routerName;
                [model1 bg_saveOrUpdate];
            } else {
                model.unReadNum = model.isHD?@(1):@(0);
                model.bg_tableName = FRIEND_CHAT_TABNAME;
                if (model.groupUserkey && ![model.groupUserkey isEmptyString]) {
                    [model bg_save];
                }
            }
        } else {
            [[ChatListDataUtil getShareObject].friendArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                FriendModel *friendModel = (FriendModel *)obj;
                if ([friendModel.userId isEqualToString:model.friendID]) {
                    NSString *nickName = friendModel.username?:@"";
                    nickName = [nickName base64DecodedString];
                    model.friendName = nickName;
                    if (friendModel.remarks && friendModel.remarks.length > 0) {
                         model.friendName = [friendModel.remarks base64DecodedString];
                    }
                    model.publicKey = friendModel.publicKey;
                    model.signPublicKey = friendModel.signPublicKey;
                    if (!model.routerName || model.routerName.length == 0) {
                        model.routerName = [friendModel.RouteName base64DecodedString]?[friendModel.RouteName base64DecodedString]:friendModel.RouteName;
                    }
                    
                    *stop = YES;
                }
            }];
            
            NSArray *friends = [ChatListModel bg_find:FRIEND_CHAT_TABNAME where:[NSString stringWithFormat:@"where %@=%@ and %@=%@ and %@=%@",bg_sqlKey(@"friendID"),bg_sqlValue(model.friendID),bg_sqlKey(@"myID"),bg_sqlValue(model.myID),bg_sqlKey(@"isGroup"),bg_sqlValue(@(0))]];
            if (friends && friends.count > 0) {
                ChatListModel *model1 = friends[0];
                model1.friendName = model.friendName;
                model1.isHD = model.isHD;
                model1.unReadNum = model.isHD?@([model1.unReadNum integerValue] + 1):model1.unReadNum;
                model1.isDraft = model.isDraft;
                if (!model1.isDraft) {
                    model1.lastMessage = model.lastMessage;
                    model1.chatTime = model.chatTime;
                }
                model1.draftMessage = model.draftMessage;
                model1.routerName = model.routerName;
                [model1 bg_saveOrUpdate];
            } else {
                model.unReadNum = model.isHD?@(1):@(0);
                model.bg_tableName = FRIEND_CHAT_TABNAME;
                if (model.publicKey && ![model.publicKey isEmptyString]) {
                    [model bg_save];
                }
            }
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:ADD_MESSAGE_NOTI object:nil];
    }
    
    
//   __block BOOL isExit = NO;
//    [self.dataArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        ChatListModel *chatModel = (ChatListModel *) obj;
//        if ([chatModel.friendID isEqualToString:model.friendID]) {
//            chatModel.lastMessage = model.lastMessage;
//            chatModel.chatTime = model.chatTime;
//            chatModel.friendName = model.friendName;
//            chatModel.publicKey = model.publicKey;
//            chatModel.isHD = model.isHD;
//            isExit = YES;
//            *stop = YES;
//        }
//    }];
//    if (!isExit) {
//        if (model.publicKey && ![model.publicKey isEmptyString]) {
//            [self.dataArray insertObject:model atIndex:0];
//        }
//        
//    }
}

- (void) removeChatModelWithFriendID:(NSString *) friendID
{
    [ChatListModel bg_delete:FRIEND_CHAT_TABNAME where:[NSString stringWithFormat:@"where %@=%@ and %@=%@",bg_sqlKey(@"friendID"),bg_sqlValue(friendID?:@""),bg_sqlKey(@"myID"),bg_sqlValue([UserConfig getShareObject].usersn)]];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADD_MESSAGE_NOTI object:nil];
}

- (void) removeGroupChatModelWithGID:(NSString *) gID
{
    [ChatListModel bg_delete:FRIEND_CHAT_TABNAME where:[NSString stringWithFormat:@"where %@=%@ and %@=%@",bg_sqlKey(@"groupID"),bg_sqlValue(gID?:@""),bg_sqlKey(@"myID"),bg_sqlValue([UserConfig getShareObject].usersn)]];
    [[NSNotificationCenter defaultCenter] postNotificationName:ADD_MESSAGE_NOTI object:nil];
}

- (void) cancelChatHDWithFriendid:(NSString *) friendid
{
    NSArray *friends = [ChatListModel bg_find:FRIEND_CHAT_TABNAME where:[NSString stringWithFormat:@"where %@=%@ and %@=%@",bg_sqlKey(@"friendID"),bg_sqlValue(friendid),bg_sqlKey(@"myID"),bg_sqlValue([UserConfig getShareObject].usersn)]];
    if (friends && friends.count > 0) {
        ChatListModel *model1 = friends[0];
        model1.isHD = NO;
        model1.unReadNum = @(0);
        [model1 bg_saveOrUpdate];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:ADD_MESSAGE_NOTI object:nil];
}
@end
