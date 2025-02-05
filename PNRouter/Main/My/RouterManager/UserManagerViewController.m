//
//  UserManagerViewController.m
//  PNRouter
//
//  Created by 旷自辉 on 2018/11/23.
//  Copyright © 2018 旷自辉. All rights reserved.
//

#import "UserManagerViewController.h"
#import "SendRequestUtil.h"
//#import "GroupCell.h"
#import "RouterUserModel.h"
#import "ContactsHeadView.h"
#import "NSString+Base64.h"
#import "ContactsCell.h"
//#import "CreateRouterUserViewController.h"
#import "AddNewMemberViewController.h"
//#import "RouterUserCodeViewController.h"
#import "RouterModel.h"
#import <MJRefresh/MJRefresh.h>
#import <MJRefresh/MJRefreshStateHeader.h>
#import <MJRefresh/MJRefreshHeader.h>
#import "InvitationQRCodeViewController.h"
#import "CircleMemberDetailViewController.h"

@interface UserManagerViewController ()<UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate>
{
    NSInteger userCount;
    NSInteger tempCount;
    BOOL isSearch;
}
@property (weak, nonatomic) IBOutlet UIView *searchBackView;
@property (weak, nonatomic) IBOutlet UITextField *searchTF;
@property (weak, nonatomic) IBOutlet UITableView *tableV;
@property (nonatomic ,strong) NSMutableArray *dataArray;
@property (nonatomic ,strong) NSMutableArray *searchDataArray;
@property (nonatomic ,strong) NSString *rid;
@property (nonatomic, assign) BOOL isRefrehing;
@property (nonatomic, assign) NSInteger startUid;

@end

@implementation UserManagerViewController
- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithRid:(NSString *)rid
{
    if (self = [super init]) {
        self.rid = rid;
    }
    return self;
}
- (IBAction)addCircleAction:(id)sender {
    
    AddNewMemberViewController *vc = [[AddNewMemberViewController alloc] initWithRid:self.rid];
    [self presentModalVC:vc animated:YES];
    
}

- (IBAction)backAction:(id)sender {
   
    [self leftNavBarItemPressedWithPop:YES];
}
#pragma mark - layz
- (NSMutableArray *)dataArray
{
    if (!_dataArray) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}
- (NSMutableArray *)searchDataArray
{
    if (!_searchDataArray) {
        _searchDataArray = [NSMutableArray array];
    }
    return _searchDataArray;
}
#pragma add observer
- (void) addObserver
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reverPullUserList:) name:USER_PULL_SUCCESS_NOTI object:nil];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _searchBackView.layer.cornerRadius = 3.0f;
    _searchTF.delegate = self;
    _searchTF.enablesReturnKeyAutomatically = YES; //这里设置为无文字就灰色不可点
    _searchTF.clearButtonMode = UITextFieldViewModeWhileEditing;
     [self addTargetMethod];
    _tableV.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    _tableV.delegate = self;
    _tableV.dataSource = self;
    _tableV.mj_header = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(refreshHeaderAction)];
    // Hide the time
    ((MJRefreshStateHeader *)_tableV.mj_header).lastUpdatedTimeLabel.hidden = YES;
    // Hide the status
    ((MJRefreshStateHeader *)_tableV.mj_header).stateLabel.hidden = YES;
    
    // 设置回调（一旦进入刷新状态就会调用这个refreshingBlock）
    @weakify_self
    _tableV.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
        [weakSelf sendPullUserListQuestWithIsRefrehing:NO];
    }];
    MJRefreshAutoNormalFooter *footerView = (MJRefreshAutoNormalFooter *)_tableV.mj_footer;
    [footerView setRefreshingTitleHidden:YES];
    [footerView setTitle:@"" forState:MJRefreshStateIdle];
    _tableV.mj_footer.hidden = YES;
    
    [_tableV registerNib:[UINib nibWithNibName:ContactsCellReuse bundle:nil] forCellReuseIdentifier:ContactsCellReuse];

    [self addObserver];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 拉取用户
    [self sendPullUserListQuestWithIsRefrehing:YES];
}

- (void) refreshHeaderAction {
    [self sendPullUserListQuestWithIsRefrehing:YES];
}

- (void) sendPullUserListQuestWithIsRefrehing:(BOOL) isRefrehing
{
    _isRefrehing = isRefrehing;
    if (isRefrehing) {
        _startUid = 0;
    }
    [SendRequestUtil sendPullUserListWithUid:_startUid showLoad:NO];
}

#pragma mark - 直接添加监听方法
-(void)addTargetMethod{
    [_searchTF addTarget:self action:@selector(textFieldTextChange:) forControlEvents:UIControlEventEditingChanged];
}

- (void) textFieldTextChange:(UITextField *) tf
{
    if ([tf.text.trim isEmptyString]) {
        isSearch = NO;
    } else {
        isSearch = YES;
        [self.searchDataArray removeAllObjects];
      //  [self.searchDataArray addObject:@[@"Create User Accounts"]];
        
        __block NSMutableArray *ptArray = [NSMutableArray array];
        __block NSMutableArray *tempArray = [NSMutableArray array];
        
        [self.dataArray[0] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            RouterUserModel *model = obj;
            NSString *userName = [model.NickName lowercaseString];
            if ([userName containsString:[tf.text.trim lowercaseString]]) {
                [ptArray addObject:model];
            }
        }];
        [self.dataArray[1] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            RouterUserModel *model = obj;
            NSString *userName = [model.NickName lowercaseString];
            if ([userName containsString:[tf.text.trim lowercaseString]]) {
                [tempArray addObject:model];
            }
        }];
        [self.searchDataArray addObject:ptArray];
        [self.searchDataArray addObject:tempArray];
    }
    [_tableV reloadData];
}
#pragma textfeild delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField endEditing:YES];
    NSLog(@"textFieldShouldReturn");
    return YES;
}

#pragma mark -UITableView delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return isSearch? self.searchDataArray.count : self.dataArray.count;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return isSearch? [self.searchDataArray[section] count] : [self.dataArray[section] count];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (isSearch ? [self.searchDataArray[section] count] == 0 : [self.dataArray[section] count] == 0) {
        return nil;
    }
    UIView *backView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 48)];
    backView.backgroundColor = [UIColor clearColor];
    ContactsHeadView *view = [ContactsHeadView loadContactsHeadView];
    view.topContraintH.constant = 0;
    if (section == 0) {
        view.lblTitle.text = [@"User" stringByAppendingString:[NSString stringWithFormat:@" (%zd/%zd)",userCount,isSearch? [self.searchDataArray[section] count] : [self.dataArray[section] count]]];
    } else {
        view.lblTitle.text = [@"Temporoay" stringByAppendingString:[NSString stringWithFormat:@" (%zd/%zd)",tempCount,isSearch? [self.searchDataArray[section] count] : [self.dataArray[section] count]]];
    }
    view.frame = backView.bounds;
    [backView addSubview:view];
    return backView;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ContactsCellHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        if (isSearch) {
            if ([self.searchDataArray[1] count] > 0) {
                return 16;
            }
        } else {
            if ([self.dataArray[1] count] > 0) {
                return 16;
            }
        }
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (isSearch ? [self.searchDataArray[section] count] == 0 : [self.dataArray[section] count] == 0) {
        return 0;
    }
    return 48;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    if (indexPath.section == 0) {
//        GroupCell *myCell = [tableView dequeueReusableCellWithIdentifier:GroupCellReuse];
//        myCell.lblName.text = isSearch? self.searchDataArray[indexPath.section][indexPath.row] :  self.dataArray[indexPath.section][indexPath.row];
//        return myCell;
//    }
    ContactsCell *myCell = [tableView dequeueReusableCellWithIdentifier:ContactsCellReuse];
    RouterUserModel *model = isSearch? self.searchDataArray[indexPath.section][indexPath.row] :  self.dataArray[indexPath.section][indexPath.row];
    [myCell setModeWithRoutherUserModel:model];
    return myCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    RouterUserModel *model = isSearch? self.searchDataArray[indexPath.section][indexPath.row] :  self.dataArray[indexPath.section][indexPath.row];

    
    CircleMemberDetailViewController *vc = [[CircleMemberDetailViewController alloc] init];
    vc.routerUserModel = model;
    [self.navigationController pushViewController:vc animated:YES];
    
}

#pragma mark - noti
- (void) reverPullUserList:(NSNotification *) noti
{
    if (_isRefrehing) {
        [_tableV.mj_header endRefreshing];
    } else {
        [_tableV.mj_footer endRefreshing];
    }

    NSArray *playod = noti.object;
    if (!playod || playod.count == 0) {
        [self.view showHint:@"Your users list is empty."];
    } else {
        // 如果是上拉就删除所有数据
        if (_isRefrehing) {
            if (self.dataArray.count > 0) {
                [self.dataArray removeAllObjects];
                userCount = 0;
                tempCount = 0;
            }
        }
        
        if (playod.count == 50) {
            self.tableV.mj_footer.hidden = NO;
        } else {
            self.tableV.mj_footer.hidden = YES;
        }
       
         __block NSMutableArray *ptArray = [NSMutableArray array];
         __block NSMutableArray *tempArray = [NSMutableArray array];
        @weakify_self
        [playod enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            RouterUserModel *model = obj;
            model.NickName = [model.NickName base64DecodedString]?:[model.Mnemonic base64DecodedString];
            model.Mnemonic = model.Mnemonic?[model.Mnemonic base64DecodedString]:@"";
            // 1 派生类。2 普通类 3 临时类
            /* if (model.UserType == 1) {
             [supperArray addObject:model];
             } else*/
            if (model.UserType == 2) {
                if (model.Active == 1) {
                    self->userCount ++;
                }
                [ptArray addObject:model];
            } else if (model.UserType == 3){
                if (model.Active == 1) {
                    self->tempCount ++;
                }
                [tempArray addObject:model];
            }
            if (idx == playod.count-1) {
                weakSelf.startUid = model.Uid;
            }
        }];
        
        if (self.dataArray.count > 0) {
            NSMutableArray *ptA = self.dataArray[0];
            NSMutableArray *tempA = self.dataArray[1];
            [ptA addObjectsFromArray:ptArray];
            [tempA addObjectsFromArray:tempArray];
            
            if (ptA.count > 0) {
                 ptArray = [self sortWith:ptA];
            }
            if (tempA.count >0) {
                tempArray = [self sortWith:tempA];
            }
            
        } else {
            
            if (ptArray.count > 0) {
                 ptArray = [self sortWith:ptArray];
            }
            if (tempArray.count >0) {
                tempArray = [self sortWith:tempArray];
            }
            [self.dataArray addObject:ptArray];
            [self.dataArray addObject:tempArray];
        }
        
        [_tableV reloadData];
    }
}

//获取其拼音
- (NSString *)huoqushouzimuWithString:(NSString *)string{
    if (!string || [string isEmptyString]) {
        return @"";
    }
    NSMutableString *ms = [[NSMutableString alloc]initWithString:string];
    CFStringTransform((__bridge CFMutableStringRef)ms, 0,kCFStringTransformStripDiacritics, NO);
    NSString *bigStr = [ms uppercaseString];
    NSString *cha = [bigStr substringToIndex:1];
    return cha;
}
//根据拼音的字母排序  ps：排序适用于所有类型
- (NSMutableArray *) sortWith:(NSMutableArray *)array{
    
    [array sortUsingComparator:^NSComparisonResult(RouterUserModel *node1, RouterUserModel *node2) {
        NSString *string1 = [NSString getNotNullValue:[self huoqushouzimuWithString:node1.NickName]];
        NSString *string2 = [NSString getNotNullValue:[self huoqushouzimuWithString:node2.NickName]];
        return [string1 compare:string2];
    }];
    return array;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
