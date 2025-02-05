//
//  PNEmailDetailViewController.m
//  PNRouter
//
//  Created by 旷自辉 on 2019/7/12.
//  Copyright © 2019 旷自辉. All rights reserved.
//

#import "PNEmailDetailViewController.h"
#import "EmailTopDetailCell.h"
#import "EmailUserCell.h"
#import "EmailTimeCell.h"
#import "EmailContentCell.h"
#import "EmailAttchView.h"
#import "EmailListInfo.h"
#import "EmailUserModel.h"
#import "NSDate+Category.h"
#import "PNEmailOptionEnumView.h"
#import "EmailAttchModel.h"
//#import <WebKit/WebKit.h>
#import "EmailOptionUtil.h"
#import "PNEmailMoveViewController.h"
#import "PNEmailSendViewController.h"
#import "NSString+HexStr.h"
#import <Masonry/Masonry.h>
#import "MCOCIDURLProtocol.h"

#import "SocketDataUtil.h"
#import "SocketManageUtil.h"
#import "SystemUtil.h"
#import "NSData+Base64.h"

#import "AESCipher.h"
#import "EmailDataBaseUtil.h"
#import "EmailAccountModel.h"
#import "NSString+Base64.h"

#import "SSZipArchive.h"
#import "MyConfidant-Swift.h"
#import "EmailNodeModel.h"
#import "RequestService.h"
#import "UserConfig.h"
#import "SendRequestUtil.h"
#import "EmailPassCell.h"
#import "EmailPassFromCell.h"
#import "PNEmailPassDefaultView.h"

#import <GoogleAPIClientForREST/GTLRBase64.h>
#import "GoogleServerManage.h"
#import "FilePreviewViewController.h"

@interface PNEmailDetailViewController ()<UITableViewDelegate,UITableViewDataSource,UIWebViewDelegate,SSZipArchiveDelegate>//WKNavigationDelegate
{
    BOOL isLoadingFinished;
    
}
@property (nonatomic ,assign) BOOL isBakNode;
@property (nonatomic ,assign) BOOL isMove;
@property (nonatomic ,assign) BOOL isHidden;
@property (weak, nonatomic) IBOutlet UILabel *lblFloderName;
@property (weak, nonatomic) IBOutlet UIButton *nodeBtn;
@property (weak, nonatomic) IBOutlet UITableView *mainTabV;
@property (nonatomic, strong) NSMutableArray *userArray;
//@property (nonatomic ,strong) WKWebView *myWebView;

@property (weak, nonatomic) IBOutlet UIScrollView *mainScrollView;
@property (nonatomic ,strong) UIWebView *myWebView;

@property (nonatomic ,strong) EmailListInfo *emailInfo;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (nonatomic ,strong) UIScrollView *wbScrollView;

@property (nonatomic, strong) PNEmailOptionEnumView *enumView;
@property (nonatomic, strong) PNEmailPassDefaultView *passDefaultView;

@property (weak, nonatomic) IBOutlet UIButton *forwardBtn;
@property (weak, nonatomic) IBOutlet UIButton *replyBtn;

@property (nonatomic, strong) NSMutableString *htmlContent;
@property (nonatomic, strong) MCOMessageParser *messageParser;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *webH;
@property (weak, nonatomic) IBOutlet UIWebView *webV;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tabH;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attchH;

@property (weak, nonatomic) IBOutlet UIView *attBackView;
@property (nonatomic, strong) EmailAttchView *attchView;
@property (nonatomic, strong) NSString *srcKey;
@property (nonatomic, strong) NSString *msgKey;
    
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nodeW;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *moreW;
@property (weak, nonatomic) IBOutlet UIView *bottomView;
@property (weak, nonatomic) IBOutlet UIView *webBackView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *backContraintV;
@property (nonatomic, strong) NSString *passWordKey;

@end

@implementation PNEmailDetailViewController

// 初始化方法
- (id)initWithEmailListModer:(EmailListInfo *)listInfo
{
    if (self = [super init]) {
        self.emailInfo = listInfo;
        
        self.emailInfo.htmlContent = [self.emailInfo.htmlContent?:@"" stringByReplacingOccurrencesOfString:@"/*<![CDATA[*/" withString:@""];
        self.emailInfo.htmlContent = [self.emailInfo.htmlContent?:@"" stringByReplacingOccurrencesOfString:@"/*]]>*/" withString:@""];
        self.emailInfo.htmlContent = [self.emailInfo.htmlContent?:@"" stringByReplacingOccurrencesOfString:@"width=" withString:@"sss="];
        self.emailInfo.htmlContent = [self.emailInfo.htmlContent?:@"" stringByReplacingOccurrencesOfString:@"width:" withString:@"sss="];
        
        if ([self.emailInfo.floderName isEqualToString:Node_backed_up]) {
            
            EmailAccountModel *accountM =[EmailAccountModel getConnectEmailAccount];
            NSString *messageId = [NSString stringWithFormat:@"%d",self.emailInfo.uid];
            NSString *filePath = [SystemUtil getDocEmailAttchFilePathWithUid:messageId user:accountM.User];
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            if (!data || data.length == 0) {
                [AppD.window showHudInView:AppD.window hint:Loading_Str];
                // 拉取邮件文件
                if ([SystemUtil isSocketConnect]) {
                    @weakify_self
                    [RequestService downFileWithBaseURLStr:self.emailInfo.EmailPath filePath:filePath progressBlock:^(CGFloat progress) {
                        
                    } success:^(NSURLSessionDownloadTask *dataTask, NSString *filePath) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                           [AppD.window hideHud];
                           NSData *attData = [NSData dataWithContentsOfFile:filePath];
                           [weakSelf parserZipWithPath:filePath data:attData];
                        });
                       
                    } failure:^(NSURLSessionDownloadTask *dataTask, NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [AppD.window hideHud];
                        });
                    }];
                } else { // tox
                    
                 //   [SendRequestUtil sendToxPullFileWithFromId:@"" toid:[UserConfig getShareObject].userId fileName:[Base58Util Base58EncodeWithCodeName:@""] filePath:self.emailInfo.EmailPath msgId:data.messageId fileOwer:@"7" fileFrom:@"3"];
                }
            } else {
                [self parserZipWithPath:filePath data:data];
            }
            
            
        } else {
            
            NSString *messageId = [NSString stringWithFormat:@"%@_%d",self.emailInfo.floderName,self.emailInfo.uid];
            if (self.emailInfo.isGoogleAPI) {
                messageId = [NSString stringWithFormat:@"%@_%@",self.emailInfo.floderName,self.emailInfo.messageid];
            }
            
            [SendRequestUtil sendEmailCheckNodeWithUid:messageId  showHud:NO];
            
            NSMutableString * html = [NSMutableString string];
            
//            [html appendFormat:@"<html><head><script>%@</script><style>%@</style></head>"
//             @"<body>%@%@%@</body><iframe src='x-mailcore-msgviewloaded:' style='width: 0px; height: 0px; border: none;'>"
//             @"</iframe></html>", mainJavascript,mainStyle,@"<div id=\"height\">", self.emailInfo.htmlContent,@"</div>"];
            
//            [html appendFormat:@"<html><head><script>%@</script><style>%@</style></head>"
//             @"<body>%@</body><iframe src='x-mailcore-msgviewloaded:' style='width: 0px; height: 0px; border: none;'>"
//             @"</iframe></html>", mainJavascript, mainStyle,self.emailInfo.htmlContent];
            
            self.htmlContent = [self adaptWebViewForHtml:self.emailInfo.htmlContent];
            
           // self.htmlContent = [NSString stringWithFormat:@"<html><body>%@</body></html>",self.emailInfo.htmlContent];
            
        
            if (self.emailInfo.parserData) {
                self.messageParser = [MCOMessageParser messageParserWithData:self.emailInfo.parserData];
            }
        }
    }
    return self;
}

//HTML适配图片文字
- (NSString *)adaptWebViewForHtml:(NSString *) htmlStr
{
    NSMutableString *headHtml = [[NSMutableString alloc] initWithCapacity:0];
     
    [headHtml appendString : @"<!DOCTYPE html>" ];
    [headHtml appendString : @"<html xmlns=\"http://www.w3.org/1999/xhtml\"xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\">" ];
    
    [headHtml appendString : @"<head>" ];
    
    [headHtml appendString : @"<meta charset=\"utf-8\">" ];
   
    [headHtml appendString : @"<meta id=\"viewport\" name=\"viewport\" content=\"width=device-width,initial-scale=0.8,maximum-scale=1.5,user-scalable=yes\" />" ];
    
    [headHtml appendString : @"<meta name=\"apple-mobile-web-app-capable\" content=\"yes\" />" ];
    
    [headHtml appendString : @"<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\" />" ];
    
    [headHtml appendString : @"<meta name=\"black\" name=\"apple-mobile-web-app-status-bar-style\" />" ];

    //适配图片宽度，让图片宽度等于屏幕宽度
    //[headHtml appendString : @"<style>img{width:100%;}</style>" ];
    //[headHtml appendString : @"<style>img{height:auto;}</style>" ];
    
     //适配图片宽度，让图片宽度最大等于屏幕宽度
//    [headHtml appendString : @"<style>img{max-width:100%;width:auto;height:auto;}</style>"];

    
   //适配图片宽度，如果图片宽度超过手机屏幕宽度，就让图片宽度等于手机屏幕宽度，高度自适应，如果图片宽度小于屏幕宽度，就显示图片大小
    [headHtml appendString : @"<script type='text/javascript'>"
     "window.onload = function(){\n"
     "var maxwidth=document.body.clientWidth;\n" //屏幕宽度
     "for(i=0;i <document.images.length;i++){\n"
     "var myimg = document.images[i];\n"
     "if(myimg.width > maxwidth){\n"
     "myimg.style.width = '100%';\n"
     "myimg.style.height = 'auto'\n;"
     "}\n"
     "}\n"
     "}\n"
     "</script>\n"];
    
    [headHtml appendString : @"<style>table{width:100%;}</style>" ];
    [headHtml appendString : @"<style>p{max-width:100%;height:auto}</style>" ];
    [headHtml appendString : @"<style>div{max-width:100%}</style>" ];
   // [headHtml appendString:@"<style>body {font-family: Helvetica;font-size: 50px;word-wrap: break-word;-webkit-text-size-adjust:none;-webkit-nbsp-mode: space;}pre {white-space: pre-wrap;}</style>" ];
    [headHtml appendString : @"<title>webview</title>" ];
    NSString *bodyHtml;
    bodyHtml = [NSString stringWithString:headHtml];
   
    bodyHtml = [bodyHtml stringByAppendingString:@"<body>"];
    /// 以下为新代码---start
    bodyHtml = [bodyHtml stringByAppendingString:@"<div id=\"height\">"];
   
    bodyHtml = [bodyHtml stringByAppendingString:htmlStr?:@""];
    bodyHtml = [bodyHtml stringByAppendingString:@"</div>"];
    bodyHtml = [bodyHtml stringByAppendingString:@"</body>"];
    bodyHtml = [bodyHtml stringByAppendingString:@"</html>"];
    return bodyHtml;
    
}

    // 解析zip
- (void) parserZipWithPath:(NSString *) path data:(NSData *) data
{
    __block NSString *unzipPath = [SystemUtil getTempEmailAttchFilePath];
    [SystemUtil removeDocmentFilePath:unzipPath];
    @weakify_self
    [SSZipArchive unzipFileAtPath:path toDestination:unzipPath overwrite:YES password:nil  progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
    } completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
        if (error) {
            // 异常
            [AppD.window showHint:Failed];
        } else {
            // 读取文件夹内容
            NSError *error = nil;
            NSMutableArray*items = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:unzipPath
                                                                                        error:&error] mutableCopy];
            if (error) {
                [AppD.window showHint:Failed];
                return;
            }
            [items enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSLog(@"解压出来对象：%lu %@",(unsigned long)idx,obj);
                // 仅仅是简单判断，方法不好
                if ([obj containsString:@".txt"]) { // 是正文
                   NSString *htmlContentPath = [unzipPath stringByAppendingPathComponent:obj];
                    NSData *htmlContentData = [NSData dataWithContentsOfFile:htmlContentPath];
                   htmlContentData = aesDecryptData(htmlContentData, [weakSelf.emailInfo.deKey dataUsingEncoding:NSUTF8StringEncoding]);
                   weakSelf.emailInfo.htmlContent = [[NSString alloc] initWithData:htmlContentData encoding:NSUTF8StringEncoding];
                    
                    NSMutableString * html = [NSMutableString string];
                    [html appendFormat:@"<html><head><script>%@</script><style>%@</style></head>"
                     @"<body>%@</body><iframe src='x-mailcore-msgviewloaded:' style='width: 0px; height: 0px; border: none;'>"
                     @"</iframe></html>", mainJavascript, mainStyle, weakSelf.emailInfo.htmlContent?:@""];
                    weakSelf.htmlContent = html;
                    [weakSelf.myWebView loadHTMLString:weakSelf.htmlContent baseURL:nil];
                } else { // 附件
                   NSString *attName = [Base58Util Base58DecodeWithCodeName:obj];
                    NSString *attPath = [unzipPath stringByAppendingPathComponent:obj];
                    NSData *attData = [NSData dataWithContentsOfFile:attPath];
                    //attData = aesDecryptData(attData, [weakSelf.emailInfo.deKey dataUsingEncoding:NSUTF8StringEncoding]);
                    EmailAttchModel *attchM = [[EmailAttchModel alloc] init];
                    attchM.attName = attName;
                    attchM.attData = attData;
                    if (!weakSelf.emailInfo.attchArray) {
                        weakSelf.emailInfo.attchArray = [NSMutableArray arrayWithCapacity:weakSelf.emailInfo.attachCount];
                    }
                    [weakSelf.emailInfo.attchArray addObject:attchM];
                }
            }];
            
            if (weakSelf.emailInfo.attachCount > 0) {
                [weakSelf.attchView setAttchs:weakSelf.emailInfo.attchArray deKey:weakSelf.emailInfo.deKey];
            }
        }
    }];
}
#pragma mark ------layz------------------
- (NSMutableArray *)userArray
{
    if (!_userArray) {
        
        _userArray = [NSMutableArray array];
        // 添加发送人
        EmailUserModel *userModel = [[EmailUserModel alloc] init];
        userModel.userType = UserFrom;
        userModel.userName = self.emailInfo.fromName;
        userModel.userAddress = self.emailInfo.From;
        [_userArray addObject:userModel];
        // 添加收送人
        if (self.emailInfo.toUserArray) {
            [_userArray addObjectsFromArray:self.emailInfo.toUserArray];
        }
        // 添加抄送人
        if (self.emailInfo.ccUserArray) {
            [_userArray addObjectsFromArray:self.emailInfo.ccUserArray];
        }
        // 添加密送人
        if (self.emailInfo.bccUserArray) {
            [_userArray addObjectsFromArray:self.emailInfo.bccUserArray];
        }
    }
    return _userArray;
}

- (PNEmailPassDefaultView *)passDefaultView
{
    if (!_passDefaultView) {
        _passDefaultView = [PNEmailPassDefaultView loadPNEmailPassDefaultView];
        @weakify_self
        [_passDefaultView setClickDecryptPassB:^(NSString *pass) {
            
            weakSelf.mainTabV.scrollEnabled = YES;
            weakSelf.mainScrollView.scrollEnabled = YES;
            
            if ([pass isEqualToString:[NSString getNotNullValue:weakSelf.emailInfo.deKey]]) {
                
                weakSelf.moreW.constant = 38;
                weakSelf.nodeW.constant = 38;
                weakSelf.passWordKey = pass;
                [weakSelf.passDefaultView hideEmailPassDefaultView];
                weakSelf.attBackView.hidden = NO;
                weakSelf.bottomView.hidden = NO;
                weakSelf.webBackView.hidden = NO;
                
                [weakSelf.myWebView loadHTMLString:weakSelf.htmlContent baseURL:nil];
                
                return ;
                
            }
            NSString *htmlContent = aesDecryptString(weakSelf.emailInfo.htmlContent?:@"", pass)?:@"";
            if (htmlContent.length > 0) {
                
                weakSelf.moreW.constant = 38;
                weakSelf.nodeW.constant = 38;
                
                htmlContent = [htmlContent stringByAppendingString:confidantHtmlStr];
                
                weakSelf.passWordKey = pass;
                weakSelf.emailInfo.deKey = pass;
                
                [weakSelf.passDefaultView hideEmailPassDefaultView];
                
                weakSelf.attBackView.hidden = NO;
                weakSelf.bottomView.hidden = NO;
                weakSelf.webBackView.hidden = NO;
               
                // 重新加载
                NSMutableString * html = [NSMutableString string];
                
                [html appendFormat:@"<html><head><script>%@</script><style>%@</style></head>"
                 @"<body>%@%@%@</body><iframe src='x-mailcore-msgviewloaded:' style='width: 0px; height: 0px; border: none;'>"
                 @"</iframe></html>", mainJavascript,mainStyle,@"<div id=\"height\">", htmlContent,@"</div>"];
                
                weakSelf.htmlContent = html;
                weakSelf.emailInfo.htmlContent = htmlContent;
                [weakSelf reloadAttch];
                [weakSelf.myWebView loadHTMLString:weakSelf.htmlContent baseURL:nil];
                
               
                
              //  weakSelf.tabH.constant -= (EmailPassCellHeight+EmailPassFromCellHeight);
             //   [weakSelf.mainTabV reloadData];
                
            } else {
                [AppD.window showHint:@"You entered a wrong password"];
            }
        }];
    }
    return _passDefaultView;
}

- (void) reloadAttch
{
    [self.attchView setAttchs:self.emailInfo.attchArray deKey:self.emailInfo.deKey];
}
#pragma makr -----IBOUT Click ----------

- (IBAction)clickForwardAction:(id)sender {
    
    if (self.emailInfo.attachCount > 0) {
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Does it include the attachment in the original email?" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        @weakify_self
        UIAlertAction *delAction = [UIAlertAction actionWithTitle:@"Including" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf forwardJumpSendVCWithAttch:YES];
        }];
        UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Not Include" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf forwardJumpSendVCWithAttch:NO];
        }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        [alertVC addAction:delAction];
        [alertVC addAction:saveAction];
        [alertVC addAction:cancelAction];
        [self presentViewController:alertVC animated:YES completion:nil];
    } else {
        [self forwardJumpSendVCWithAttch:NO];
    }
}
- (void) forwardJumpSendVCWithAttch:(BOOL) isAttch
{
    if (isAttch) {
        if (self.emailInfo.attchArray) {
            __block BOOL isDown = NO;
            [self.emailInfo.attchArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                EmailAttchModel *attchM = obj;
                if (attchM.downStatus != 2) {
                    isDown = YES;
                    *stop = YES;
                }
            }];
            if (isDown) {
                [self.view showHint:@"Downloading the attachment, please try again later."];
                return;
            }
        }
    }
    PNEmailSendViewController *vc = [[PNEmailSendViewController alloc] initWithEmailListInfo:self.emailInfo sendType:ForwardEmail isShowAttch:isAttch];
    [self presentModalVC:vc animated:YES];
}
- (IBAction)clickReplyAction:(id)sender {
    
    PNEmailSendViewController *vc = [[PNEmailSendViewController alloc] initWithEmailListInfo:self.emailInfo sendType:ReplyEmail];
    [self presentModalVC:vc animated:YES];
    // 回复
    // 构建邮件体的发送内容
    /*
    MCOMessageBuilder *messageBuilder = [[MCOMessageBuilder alloc] init];
    messageBuilder.header.from = [MCOAddress addressWithDisplayName:@"张三" mailbox:@"111111@qq.com"];   // 发送人
    messageBuilder.header.to = @[[MCOAddress addressWithMailbox:@"222222@qq.com"]];       // 收件人（多人）
    messageBuilder.header.cc = @[[MCOAddress addressWithMailbox:@"@333333qq.com"]];      // 抄送（多人）
    messageBuilder.header.bcc = @[[MCOAddress addressWithMailbox:@"444444@qq.com"]];    // 密送（多人）
    messageBuilder.header.subject = @"测试邮件";    // 邮件标题
    messageBuilder.textBody = @"hello world";           // 邮件正文
    
    
    // 如果邮件是回复或者转发，原邮件中往往有附件以及正文中有其他图片资源，
    // 如果有需要你可将原文原封不动的也带过去，这里发送的正文就可以如下配置
     
    NSString * bodyHtml = @"<p>我是原邮件正文</p>";
    NSString *body = @"我是邮件回复的内容";
    NSMutableString*fullBodyHtml = [NSMutableString stringWithFormat:@"%@<br/>-------------原始邮件-------------<br/>%@",[body stringByReplacingOccurrencesOfString:@"\n"withString:@"<br/>"],bodyHtml];
    [messageBuilder setHTMLBody:fullBodyHtml];
    
    // 添加正文里的附加资源
    NSArray *inattachments = msgPaser.htmlInlineAttachments;
    for (MCOAttachment*attachmentininattachments) {
        [messageBuilder addRelatedAttachment:attachment];    //添加html正文里的附加资源（图片）
    }
    
    // 添加邮件附件
    for (MCOAttachment*attachmentinattachments) {
        [builder addAttachment:attachment];    //添加附件
    }
    */
}
- (IBAction)clickBackBtn:(id)sender {
    if (_isMove) {
        [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(2)];
    }
    if ([self.emailInfo.floderName isEqualToString:Starred]) {
         BOOL isStar = [EmailOptionUtil checkEmailStar:self.emailInfo.Read];
        if (!isStar) { // 星标文件夹取消星标
            [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(4)];
        }
        
    }
    [self leftNavBarItemPressedWithPop:YES];
}
- (IBAction)ClickRightBtn:(UIButton *)sender {
    if (sender.tag == 30) {
        if (!self.enumView) {
            self.enumView = [PNEmailOptionEnumView loadPNEmailOptionEnumView];
            @weakify_self
            [self.enumView setEmumBlock:^(NSInteger row) {
                if (row == 0) { //设为未读
                    if (weakSelf.emailInfo.Read == 0) {
                        return;
                    }
                    [weakSelf.view showHudInView:weakSelf.view hint:@""];
                    [EmailOptionUtil setEmailReaded:NO uid:weakSelf.emailInfo.uid messageId:weakSelf.emailInfo.messageid folderPath:weakSelf.emailInfo.floderPath complete:^(BOOL success) {
                        [weakSelf.view hideHud];
                        if (!success) {
                            [weakSelf.view showFaieldHudInView:weakSelf.view hint:@"Failure."];
                        } else {
                            [weakSelf.view showSuccessHudInView:weakSelf.view hint:@"Successed"];
                            weakSelf.emailInfo.Read -=1;
                            
                            [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(0)];
                        }
                    }];
                } else if (row == 1) { // 设为star
                    [weakSelf.view showHudInView:weakSelf.view hint:@""];
                    
                    BOOL isStar = [EmailOptionUtil checkEmailStar:weakSelf.emailInfo.Read];
                    
                    [EmailOptionUtil setEmailStaredUid:weakSelf.emailInfo.uid messageId:weakSelf.emailInfo.messageid folderPath:weakSelf.emailInfo.floderPath isAdd:isStar? NO:YES  complete:^(BOOL success) {
                        [weakSelf.view hideHud];
                        if (!success) {
                            [weakSelf.view showFaieldHudInView:weakSelf.view hint:@"Failure."];
                        } else {
                            
                            [weakSelf.view showSuccessHudInView:weakSelf.view hint:@"Successed"];
                            weakSelf.emailInfo.Read = isStar?weakSelf.emailInfo.Read-4:weakSelf.emailInfo.Read+4;
                            [weakSelf.mainTabV reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                            
                            if (![weakSelf.emailInfo.floderName isEqualToString:Starred]) {
                                [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(1)];
                            }
                            
                            if (!weakSelf.emailInfo.isGoogleAPI) {
                                
                                if (isStar) { // 取消star
                                    [EmailDataBaseUtil delEmialStarWithEmialInfo:weakSelf.emailInfo];
                                } else { // star
                                    // 保存数据
                                    if (weakSelf.emailInfo.toUserArray && weakSelf.emailInfo.toUserArray.count > 0) {
                                        weakSelf.emailInfo.ToJson = [[EmailUserModel mj_keyValuesArrayWithObjectArray:weakSelf.emailInfo.toUserArray] mj_JSONString];
                                    }
                                    if (weakSelf.emailInfo.ccUserArray && weakSelf.emailInfo.ccUserArray.count > 0) {
                                        weakSelf.emailInfo.ccJsons = [[EmailUserModel mj_keyValuesArrayWithObjectArray:weakSelf.emailInfo.ccUserArray] mj_JSONString];
                                    }
                                    if (weakSelf.emailInfo.bccUserArray && weakSelf.emailInfo.bccUserArray.count > 0) {
                                        weakSelf.emailInfo.bccJsons = [[EmailUserModel mj_keyValuesArrayWithObjectArray:weakSelf.emailInfo.bccUserArray] mj_JSONString];
                                    }
                                    [EmailDataBaseUtil addEmialStarWithEmialInfo:weakSelf.emailInfo];
                                }
                                
                            }
                            
                        }
                    }];
                } else if (row == 2) { // 保存节点
                    if ([SystemUtil isSocketConnect]) {
                         [weakSelf saveEmailToNode];
                    }
                   
                } else if (row == 3) { // 移动to
                    
                    NSString *messageId = [NSString stringWithFormat:@"%d",weakSelf.emailInfo.uid];
                    if (weakSelf.emailInfo.isGoogleAPI) {
                        messageId = weakSelf.emailInfo.messageid;
                    }
                    PNEmailMoveViewController *vc = [[PNEmailMoveViewController alloc] initWithFloderPath:weakSelf.emailInfo.floderPath uid:messageId isGoole:weakSelf.emailInfo.isGoogleAPI];
                    [vc setMoveBlock:^{
                         [weakSelf.view showSuccessHudInView:weakSelf.view hint:@"Successed"];
                        weakSelf.isMove = YES;
                    }];
                    [weakSelf presentModalVC:vc animated:YES];
                    
                } else if (row == 4) { // 删除
                    if ([weakSelf.emailInfo.floderName isEqualToString:Node_backed_up]) {
                        
                    } else {
                        // 是本地加星
                        if ([weakSelf.emailInfo.floderName isEqualToString:Starred] && !weakSelf.emailInfo.isGoogleAPI) {
                            
                            [EmailDataBaseUtil delEmialStarWithEmialInfo:weakSelf.emailInfo];
                            
                            [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(3)];
                            [weakSelf leftNavBarItemPressedWithPop:YES];
                            return;
                        }
                        [weakSelf.view showHudInView:weakSelf.view hint:@""];
                        [EmailOptionUtil deleteEmailUid:weakSelf.emailInfo.uid messageId:weakSelf.emailInfo.messageid folderPath:weakSelf.emailInfo.floderPath folderName:weakSelf.emailInfo.floderName complete:^(BOOL success) {
                            [weakSelf.view hideHud];
                            if (success) {
                                [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(3)];
                                [weakSelf leftNavBarItemPressedWithPop:YES];
                            } else {
                                [weakSelf.view showFaieldHudInView:weakSelf.view hint:@"Failure."];
                            }
                        }];
                    }
                }
            }];
        }
        BOOL isShowMove = NO;
        if ([self.emailInfo.floderName isEqualToString:Inbox] && !_isMove) {
            isShowMove = YES;
        }
        BOOL isStar = [EmailOptionUtil checkEmailStar:self.emailInfo.Read];
        self.enumView.isBakUp = _isBakNode;
        [self.enumView showEmailOptionEnumViewWithStar:isStar? YES:NO isShowMove:isShowMove];
        
    } else if (sender.tag == 20) { // 删除邮件
        
        if ([self.emailInfo.floderName isEqualToString:Node_backed_up]) {
            NSString *messageId = self.emailInfo.uid>0 ? [NSString stringWithFormat:@"%d",self.emailInfo.uid] : self.emailInfo.messageid;
            [SendRequestUtil sendEmailDelNodeWithUid:messageId showHud:YES];
            return;
        }
        // 是本地加星
        if ([self.emailInfo.floderName isEqualToString:Starred] && !self.emailInfo.isGoogleAPI) {
            
            [EmailDataBaseUtil delEmialStarWithEmialInfo:self.emailInfo];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(3)];
            [self leftNavBarItemPressedWithPop:YES];
            return;
        }
        
        [self.view showHudInView:self.view hint:@""];
        @weakify_self
        [EmailOptionUtil deleteEmailUid:weakSelf.emailInfo.uid messageId:weakSelf.emailInfo.messageid folderPath:weakSelf.emailInfo.floderPath folderName:weakSelf.emailInfo.floderName complete:^(BOOL success) {
            [weakSelf.view hideHud];
            if (success) {
                [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(3)];
                [weakSelf leftNavBarItemPressedWithPop:YES];
            } else {
                [weakSelf.view showFaieldHudInView:weakSelf.view hint:@"Failure."];
            }
        }];
    } else {
        if ([SystemUtil isSocketConnect]) {
            [self saveEmailToNode];
        }
    }
}


- (void)viewDidLoad {
    
    [super viewDidLoad];
    if (self.emailInfo.passHint.length == 0) {
         self.view.backgroundColor = MAIN_GRAY_COLOR;
    } else {
        self.moreW.constant = 0;
        self.nodeW.constant = 0;
    }
    _passWordKey = @"";
    _forwardBtn.layer.cornerRadius = 8.0f;
    _forwardBtn.layer.masksToBounds = YES;
    
    _replyBtn.layer.cornerRadius = 8.0f;
    _replyBtn.layer.masksToBounds = YES;
    _replyBtn.layer.borderColor = MAIN_PURPLE_COLOR.CGColor;
    _replyBtn.layer.borderWidth = 1.0f;
    
    [self addNotis];
    
    _lblFloderName.text = self.emailInfo.floderName;
    
    _isHidden = YES;
    _mainTabV.delegate = self;
    _mainTabV.dataSource = self;
    _mainTabV.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    _mainTabV.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_mainTabV registerNib:[UINib nibWithNibName:EmailTopDetailCellResue bundle:nil] forCellReuseIdentifier:EmailTopDetailCellResue];
    [_mainTabV registerNib:[UINib nibWithNibName:EmailUserCellResue bundle:nil] forCellReuseIdentifier:EmailUserCellResue];
    [_mainTabV registerNib:[UINib nibWithNibName:EmailTimeCellResue bundle:nil] forCellReuseIdentifier:EmailTimeCellResue];
    [_mainTabV registerNib:[UINib nibWithNibName:EmailPassCellResu bundle:nil] forCellReuseIdentifier:EmailPassCellResu];
    [_mainTabV registerNib:[UINib nibWithNibName:EmailPassFromCellResu bundle:nil] forCellReuseIdentifier:EmailPassFromCellResu];
    
    
//    [_progressView setTrackTintColor:[UIColor colorWithRed:240.0/255
//                                                     green:240.0/255
//                                                      blue:240.0/255
//                                                     alpha:1.0]];
//    _progressView.progressTintColor = [UIColor greenColor];
//    // 添加进度观察者
//    [_myWebView addObserver:self
//                 forKeyPath:NSStringFromSelector(@selector(estimatedProgress))
//                    options:0
//                    context:nil];
    
    self.myWebView = self.webV;
    self.wbScrollView = self.myWebView.scrollView;
    self.wbScrollView.bounces = NO;
    //           self.wbScrollView.scrollEnabled = NO;
    //            self.myWebView.delegate = self;
    self.myWebView.scalesPageToFit = YES;
    [self.myWebView setAutoresizingMask:(UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth)];
    self.myWebView.opaque = NO; //去掉底部黑色
    [self.myWebView setDelegate:self];
    
    
    if (self.emailInfo.attachCount > 0) {
        CGFloat itemW = (SCREEN_WIDTH-32-4)/2;
        CGFloat itemH = itemW*(128.0/170);
        CGFloat rows = self.emailInfo.attachCount/2 + self.emailInfo.attachCount%2;
        _attchH.constant = rows*itemH+((rows-1)*4)+32+35;
        
        _attchView = [[[NSBundle mainBundle] loadNibNamed:@"EmailAttchView" owner:self options:nil] lastObject];
        _attchView.frame = CGRectZero;
        _attchView.messageId = self.emailInfo.messageid;
        [_attBackView addSubview:_attchView];
        
        @weakify_self
        [_attchView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.left.right.mas_equalTo(weakSelf.attBackView).offset(0);
        }];
        if (self.emailInfo.passHint.length == 0) {
             [_attchView setAttchs:self.emailInfo.attchArray deKey:self.emailInfo.deKey];
        }
       
        [_attchView setClickAttBlock:^(NSInteger selItem) {
            EmailAttchModel *model = weakSelf.emailInfo.attchArray[selItem];
            if (weakSelf.emailInfo.deKey && weakSelf.emailInfo.deKey.length > 0) {
                
                FilePreviewViewController*vc = [[FilePreviewViewController alloc] init];
                vc.fileType = EmailFile;
                vc.localFileData = aesDecryptData(model.attData, [weakSelf.emailInfo.deKey dataUsingEncoding:NSUTF8StringEncoding]);
                vc.fileName = model.attName;
                [weakSelf.navigationController pushViewController:vc animated:YES];
                
            } else {
                FilePreviewViewController*vc = [[FilePreviewViewController alloc] init];
                vc.fileType = EmailFile;
                vc.localFileData = model.attData;
                vc.fileName = model.attName;
                [weakSelf.navigationController pushViewController:vc animated:YES];
            }
            
           
        }];
        
    } else {
        _attchH.constant = 0;
    }
    
    if ([self.emailInfo.floderName isEqualToString:Node_backed_up]) {
        _nodeW.constant = 0;
        _moreW.constant = 0;
    }
    
    _webH.constant = SCREEN_HEIGHT - NAVIGATION_BAR_HEIGHT - 128 - 82 - HOME_INDICATOR_HEIGHT - _attchH.constant;
    if (self.emailInfo.passHint.length > 0) {
        _attBackView.hidden = YES;
        _bottomView.hidden = YES;
        _webBackView.hidden = YES;
    } else {
        [self.myWebView loadHTMLString:self.htmlContent baseURL:nil];
    }
    
  
    
    if (self.emailInfo.passHint && self.emailInfo.passHint.length > 0) {
        
        self.mainTabV.scrollEnabled = NO;
        self.mainScrollView.scrollEnabled = NO;
        if (![self.emailInfo.passHint isEqualToString:@"0"]) {
             self.passDefaultView.lblPassHint.text = [NSString stringWithFormat:@"Passwork Hint: %@",self.emailInfo.passHint];
        }
        [self.passDefaultView showEmailPassDefaultView:self.view frameY:128+NAVIGATION_BAR_HEIGHT];
        
    }
   
}

#pragma mark --------------添加通知------
- (void) addNotis {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emailFileUploadNoti:) name:EMIAL_UPLOAD_NODE_NOTI object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emailUploadNodeNoti:) name:EMAIL_NODE_UPLOAD_NOTI object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emailDelNodeNoti:) name:EMAIL_DEL_NODE_NOTI object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkEmailBakNodeNoti:) name:EMAIL_BAK_NODE_NOTI object:nil];
    
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
//    NSString *hintStr = [NSString getNotNullValue:self.emailInfo.passHint];
//    if (hintStr.length > 0 && _passWordKey.length == 0) {
//        return 2;
//    }
    return 1;
}
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    if (section == 0) {
        if (_isHidden) {
            return 1;
        } else {
            return self.userArray.count+2;
        }
    } else if (section == 1) {
        return 2;
    } else if (section == 2) {
        if (self.emailInfo.attachCount > 0) {
            return 1;
        }
    }
    return 0;
}
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
           return EmailTopDetailCellDefaultHeight;
        } else if (indexPath.row <= self.userArray.count) {
            return EmailUserCellHeight;
        } else {
            return EmailTimeCellHeight;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            return EmailPassCellHeight;
        } else {
            return EmailPassFromCellHeight;
        }
    }
    return 0;
}
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            EmailTopDetailCell *cell = [tableView dequeueReusableCellWithIdentifier:EmailTopDetailCellResue];
          //  NSString *hintStr = [NSString getNotNullValue:self.emailInfo.passHint];
            if (_isHidden) {
                [cell.hiddenBtn setTitle:@"Details" forState:UIControlStateNormal];
                cell.lineView.hidden = NO;
                
                _tabH.constant = 128;
                
            } else {
                cell.lineView.hidden = YES;
                [cell.hiddenBtn setTitle:@"Hide" forState:UIControlStateNormal];
                _tabH.constant = 128+(_userArray.count*37)+33;
                
            }
            [cell setEmialInfoModel:self.emailInfo];
            @weakify_self
            [cell setHiddenBlock:^(NSInteger tag){
                if (tag == 10) {
                    weakSelf.isHidden = !weakSelf.isHidden;
                    [weakSelf.mainTabV reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
                } else {
                    [weakSelf.mainScrollView setContentOffset:CGPointMake(0, weakSelf.mainScrollView.contentSize.height- weakSelf.mainScrollView.bounds.size.height) animated:YES];
                }
            }];
            return cell;
        } else if (indexPath.row <= self.userArray.count) {
            EmailUserCell *cell = [tableView dequeueReusableCellWithIdentifier:EmailUserCellResue];
            EmailUserModel *model = [self.userArray objectAtIndex:indexPath.row-1];
            [cell setUserModel:model];
            return cell;
        } else {
            EmailTimeCell *cell = [tableView dequeueReusableCellWithIdentifier:EmailTimeCellResue];
            cell.lblTime.text = [self.emailInfo.revDate formattedDateYearYueRi:@"dd/MM/yyy HH:mm"];
            return cell;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            EmailPassCell *cell = [tableView dequeueReusableCellWithIdentifier:EmailPassCellResu];
            return cell;
        } else {
            EmailPassFromCell *cell = [tableView dequeueReusableCellWithIdentifier:EmailPassFromCellResu];
            cell.lblFrom.text = self.emailInfo.From;
            // 显示输入密码
//            [cell setClickEncodeB:^{
//
//            }];
            return cell;
        }
    } 
    return nil;
}




#pragma mark ------------webview -------------------------
//获取宽度已经适配于webView的html。这里的原始html也可以通过js从webView里获取
- (NSString *)htmlAdjustWithPageWidth:(CGFloat )pageWidth
                                 html:(NSString *)html
                              webView:(UIWebView *)webView
{
    NSMutableString *str = [NSMutableString stringWithString:html];
    //计算要缩放的比例
    CGFloat initialScale = webView.frame.size.width/pageWidth;
    if (initialScale > 1) {
        initialScale = 1;
    }
    NSLog(@"----initialScale = %f---------",initialScale);
    //将</head>替换为meta+head
    NSString *stringForReplace = [NSString stringWithFormat:@"<meta name=\"viewport\" content=\" initial-scale=%f, minimum-scale=0.1, maximum-scale=2.0, user-scalable=yes\"></head>",initialScale];
    
    NSRange range =  NSMakeRange(0, str.length);
    //替换
    [str replaceOccurrencesOfString:@"</head>" withString:stringForReplace options:NSLiteralSearch range:range];
    return str;
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"----didFailLoadWithError---------");

}
-(void)webViewDidFinishLoad:(UIWebView *)webView{
    NSLog(@"----webViewDidFinishLoad---------");
    //若已经加载完成，则显示webView并return
    if(!isLoadingFinished)
    {
        
//        CGSize contentSize = webView.scrollView.contentSize; //设置内容板块的尺寸
//        CGSize viewSize = self.view.bounds.size;//自适应边界值
//        viewSize.width-=32;
//        float sfactor = viewSize.width / contentSize.width;//调整因子计算
//        webView.scrollView.minimumZoomScale = sfactor;//最大调整参数设置为调整因子
//        webView.scrollView.maximumZoomScale = sfactor;//最小调整参数设置为调整因子
//        webView.scrollView.zoomScale = 1.5; //设置本身无缩放，自适应
//
//        webView.scrollView.contentSize = CGSizeMake(webView.scrollView.contentSize.width*sfactor, webView.scrollView.contentSize.height*sfactor);
        
        
       // [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '150%'"];
        
        NSString *jsStr = @"function reSetImgFrame() { \
        var imgs = document.getElementsByTagName('img'); \
        for (var i = 0; i < imgs.length; i++) {\
        var img = imgs[i];   \
        var imgW = img.getAttribute('width');   \
        var imgH = img.getAttribute('height');   \
        img.style.maxWidth = %f;   \
        img.style.maxHeight = imgH*(%f/imgW);   \
        } \
        }";
        jsStr = [NSString stringWithFormat:jsStr,SCREEN_WIDTH,SCREEN_WIDTH];
        [webView stringByEvaluatingJavaScriptFromString:jsStr];
        [webView stringByEvaluatingJavaScriptFromString:@"reSetImgFrame()"];
        
        
        CGFloat newHeight =  [[webView stringByEvaluatingJavaScriptFromString: @"document.body.scrollHeight "] floatValue];
        
        newHeight = webView.scrollView.contentSize.height;
        NSLog(@"--%f---%f",newHeight,webView.scrollView.contentSize.height);
        
        if (newHeight > (SCREEN_HEIGHT-NAVIGATION_BAR_HEIGHT-82-100)) {
            _webH.constant = SCREEN_HEIGHT-NAVIGATION_BAR_HEIGHT-82-100;
        } else if (newHeight > _webH.constant) {
            _webH.constant = newHeight;
        }
        return;
    }
    
    //js获取body宽度
    NSString *bodyWidth= [webView stringByEvaluatingJavaScriptFromString: @"document.body.scrollWidth "];
    
    int widthOfBody = [bodyWidth intValue];
    
    //获取实际要显示的html
    NSString *html = [self htmlAdjustWithPageWidth:widthOfBody
                                              html:self.emailInfo.htmlContent?:@""
                                           webView:webView];
    self.emailInfo.htmlContent = html?:@"";
    //设置为已经加载完成
    isLoadingFinished = YES;
    
    // [self.mainTabV reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    
    //加载实际要现实的html
    [self.myWebView loadHTMLString:html baseURL:nil];
    
}



-(void)dealloc{
  //  [_myWebView removeObserver:self
                    //forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
    _myWebView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}




#pragma mark - webview

- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString* requestURL = request.URL.absoluteString;

    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:requestURL] options:@{} completionHandler:^(BOOL success) {

        }];
        return NO;
    } else {
        NSURLRequest*responseRequest = [self webView:webView resource:nil willSendRequest:request redirectResponse:nil fromDataSource:nil];
        if(responseRequest== request) {
            return YES;
        } else {
            [webView loadRequest:responseRequest];
            return NO;
        }
    }
//    NSURLRequest*responseRequest = [self webView:webView resource:nil willSendRequest:request redirectResponse:nil fromDataSource:nil];
//    if(responseRequest== request) {
//        return YES;
//    } else {
//        [webView loadRequest:responseRequest];
//        return NO;
//    }
}

- (NSURLRequest *)webView:(UIWebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(id)dataSource

{
   if ([[[request URL] scheme] isEqualToString:@"x-mailcore-msgviewloaded"]) {
        [self _loadImages];
   }
    return request;
}

//加载网页中的图片

- (void) _loadImages

{
    NSString * result = [self.myWebView stringByEvaluatingJavaScriptFromString:@"findCIDImageURL()"];
    
    NSLog(@"-----加载网页中的图片-----");
    
    NSLog(@"cid = %@", result);
    
    if (result==nil || [result isEqualToString:@""]) {
        return;
    }
    
    NSData * data = [result dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSArray * imagesURLStrings = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    for(NSString * urlString in imagesURLStrings) {
        MCOAbstractPart * part =nil;
        NSURL * url;
        url = [NSURL URLWithString:urlString];
        if (!url) {
            continue;
        }
        if ([MCOCIDURLProtocol isCID:url]) {
            part = [self _partForCIDURL:url];
        } else if ([MCOCIDURLProtocol isXMailcoreImage:url]) {
            NSString * specifier = [url resourceSpecifier];
            NSString * partUniqueID = specifier;
            part = [self _partForUniqueID:partUniqueID];
        }
        if (part == nil && !self.emailInfo.isGoogleAPI)
            continue;
        
        if (self.emailInfo.isGoogleAPI) {
            //获取文件路径
            __block EmailAttchModel *attM = nil;
            [self.emailInfo.cidArray enumerateObjectsUsingBlock:^(EmailAttchModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([urlString containsString:obj.cid]) {
                    attM = obj;
                    *stop = YES;
                }
            }];
            if (attM) {
                NSString *tmpDirectory =NSTemporaryDirectory();
                NSString *filePath=[tmpDirectory stringByAppendingPathComponent:attM.attName];
                NSFileManager *fileManger=[NSFileManager defaultManager];
                
                if (![fileManger fileExistsAtPath:filePath]) {//不存在就去请求加载
                    
                    [self downCidFileWithAttMode:attM filePath:filePath urlString:urlString];
                    
                } else {
                    attM.attData = [NSData dataWithContentsOfFile:filePath];
                    NSURL * cacheURL = [NSURL fileURLWithPath:filePath];
                    NSDictionary * args =@{@"URLKey": urlString,@"LocalPathKey": cacheURL.absoluteString};
                    NSString * jsonString = [self _jsonEscapedStringFromDictionary:args];
                    NSString * replaceScript = [NSString stringWithFormat:@"replaceImageSrc(%@)", jsonString];
                    [self.myWebView stringByEvaluatingJavaScriptFromString:replaceScript];
                }
                
            }
           
            
            
        } else {
            NSString * partUniqueID = [part uniqueID];
            MCOAttachment * attachment = (MCOAttachment *) [_messageParser partForUniqueID:partUniqueID];
            NSData * data =[attachment data];
            if (data!=nil) {
                //获取文件路径
                NSString *tmpDirectory =NSTemporaryDirectory();
                NSString *filePath=[tmpDirectory stringByAppendingPathComponent :[NSString stringWithFormat:@"%@%@",attachment.filename,partUniqueID]];
                NSFileManager *fileManger=[NSFileManager defaultManager];
                
                if (![fileManger fileExistsAtPath:filePath]) {//不存在就去请求加载
                    NSData *attachmentData=[attachment data];
                    if (_emailInfo.deKey && _emailInfo.deKey.length > 0) {
                        attachmentData = aesDecryptData(attachmentData, [self.emailInfo.deKey dataUsingEncoding:NSUTF8StringEncoding]);
                    }
                    [attachmentData writeToFile:filePath atomically:YES];
                    NSLog(@"资源：%@已经下载至%@", attachment.filename,filePath);
                }
                NSURL * cacheURL = [NSURL fileURLWithPath:filePath];
                
                NSDictionary * args =@{@"URLKey": urlString,@"LocalPathKey": cacheURL.absoluteString};
                NSString * jsonString = [self _jsonEscapedStringFromDictionary:args];
                NSString * replaceScript = [NSString stringWithFormat:@"replaceImageSrc(%@)", jsonString];
                [self.myWebView stringByEvaluatingJavaScriptFromString:replaceScript];
            }
        }
        
    }
}

// 下载 cid 文件
- (void) downCidFileWithAttMode:(EmailAttchModel *) attM filePath:(NSString *)filePath urlString:(NSString *) urlString
{
    // 下载cid 文件
    EmailAccountModel *accountM = [EmailAccountModel getConnectEmailAccount];
    GTLRGmailQuery_UsersMessagesAttachmentsGet *list = [GTLRGmailQuery_UsersMessagesAttachmentsGet queryWithUserId:accountM.userId messageId:self.emailInfo.messageid identifier:attM.attId];
    
    @weakify_self
    [[GoogleServerManage getGoogleServerManageShare].gmailService executeQuery:list completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (!callbackError) {
            GTLRObject *gltM = object;
            NSString *dataStr = gltM.JSON[@"data"]?:@"";
            if (dataStr.length > 0) {
                NSData *contentData = GTLRDecodeWebSafeBase64(dataStr);
                if (weakSelf.emailInfo.deKey && weakSelf.emailInfo.deKey.length > 0) {
                    contentData = aesDecryptData(contentData, [weakSelf.emailInfo.deKey dataUsingEncoding:NSUTF8StringEncoding]);
                }
                attM.attData = contentData;
                // 保存到本地
                [contentData writeToFile:filePath atomically:YES];
                
                NSURL * cacheURL = [NSURL fileURLWithPath:filePath];
                NSDictionary * args =@{@"URLKey": urlString,@"LocalPathKey": cacheURL.absoluteString};
                NSString * jsonString = [weakSelf _jsonEscapedStringFromDictionary:args];
                NSString * replaceScript = [NSString stringWithFormat:@"replaceImageSrc(%@)", jsonString];
                [weakSelf.myWebView stringByEvaluatingJavaScriptFromString:replaceScript];
            }
        }
    }];
}

- (NSString *)_jsonEscapedStringFromDictionary:(NSDictionary *)dictionary

{
    NSData * json = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    NSString * jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    return jsonString;
    
}

- (NSURL *) _cacheJPEGImageData:(NSData *)imageData withFilename:(NSString *)filename

{
    NSString * path = [[NSTemporaryDirectory()stringByAppendingPathComponent:filename]stringByAppendingPathExtension:@"jpg"];
    [imageData writeToFile:path atomically:YES];
    return [NSURL fileURLWithPath:path];
    
}

- (MCOAbstractPart *) _partForCIDURL:(NSURL *)url

{
    if (!_messageParser) {
        return nil;
    }
    return [_messageParser partForContentID:[url resourceSpecifier]];
}

- (MCOAbstractPart *) _partForUniqueID:(NSString *)partUniqueID

{
    if (!_messageParser) {
        return nil;
    }
    return [_messageParser partForUniqueID:partUniqueID];
    
}

#pragma mark ---------------保存到节点-------------
- (void) saveEmailToNode
{
    if (_isBakNode) {
        [AppD.window showHint:@"This email has been backed up"];
        return;
    }
    
    if (self.emailInfo.attchArray) {
        __block BOOL isDown = NO;
        [self.emailInfo.attchArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            EmailAttchModel *attchM = obj;
            if (attchM.downStatus != 2) {
                isDown = YES;
                *stop = YES;
            }
        }];
        if (isDown) {
            [self.view showHint:@"Downloading the attachment, please try again later."];
            return;
        }
    }
    
    [AppD.window showHudInView:AppD.window hint:Uploading_Str];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSString *fileid = [NSString stringWithFormat:@"%llu",[NSDate getMillisecondTimestampFromDate:[NSDate date]]];
        // 生成32位对称密钥
        self.msgKey = [SystemUtil get32AESKey];
        
        NSData *symmetData =[self.msgKey dataUsingEncoding:NSUTF8StringEncoding];
        NSString *symmetKey = [symmetData base64EncodedString];
        
        // 自己公钥加密对称密钥
        self.srcKey =[LibsodiumUtil asymmetricEncryptionWithSymmetry:symmetKey enPK:[EntryModel getShareObject].publicKey];
        
        NSData *msgKeyData =[[self.msgKey substringToIndex:16] dataUsingEncoding:NSUTF8StringEncoding];
        // 加密正文内容
        NSString *content = self.emailInfo.htmlContent?:@"";
        NSData *contetnData = [content dataUsingEncoding:NSUTF8StringEncoding];
        contetnData = aesEncryptData(contetnData, msgKeyData);
        
        // 压宿到的路经
        NSString *zipPath = [SystemUtil getTempEmailAttchFilePath];
        NSString *zipName = [NSString stringWithFormat:@"%ld",[NSDate getTimestampFromDate:[NSDate date]]];
        zipPath = [zipPath stringByAppendingPathComponent:[zipName stringByAppendingString:@".zip"]];
        
        NSString *emailPath = [[SystemUtil getTempEmailAttchFilePath] stringByAppendingPathComponent:@"htmlContent.txt"];
        NSMutableArray *files = [NSMutableArray array];
        __block BOOL isfinsh = [contetnData writeToFile:emailPath atomically:YES];
        if (isfinsh) {
            [files addObject:emailPath];
        }
        @weakify_self
        [self.emailInfo.attchArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            EmailAttchModel *attchM = obj;
            if (attchM.attData) {
                
                NSString *attchName = [Base58Util Base58EncodeWithCodeName:attchM.attName?:@""]?:@"";
                NSString *attchPath = [[SystemUtil getTempEmailAttchFilePath] stringByAppendingPathComponent:attchName];
                NSData *attData = nil;
                if (weakSelf.emailInfo.deKey && weakSelf.emailInfo.deKey.length > 0) {
                    attData = aesDecryptData(attchM.attData, [weakSelf.emailInfo.deKey dataUsingEncoding:NSUTF8StringEncoding]);
                } else {
                    attData = attchM.attData;
                }
                attData = aesEncryptData(attData, msgKeyData);
                isfinsh = [attData writeToFile:attchPath atomically:YES];
                if (isfinsh) {
                    [files addObject:attchPath];
                }
            }
           
        }];
        BOOL success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:files];
        if (success) {
            NSData *enData = [NSData dataWithContentsOfFile:zipPath];
            dispatch_async(dispatch_get_main_queue(), ^{
                SocketDataUtil *dataUtil = [[SocketDataUtil alloc] init];
                [dataUtil sendEmailToId:@"" fileName:fileid fileData:enData fileid:fileid fileType:7 srcKey:weakSelf.srcKey];
                [[SocketManageUtil getShareObject].socketArray addObject:dataUtil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [AppD.window hideHud];
                [AppD.window showFaieldHudInView:AppD.window hint:@"Failed to Upload"];
            });
        }
    });
    
    
//    if (success) {
//        // 解压后文件夹的路径
//        NSString *unzipPath = [NSString stringWithFormat:@"%@/\%@", NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0],@"ds_files"];
//
//        NSURL *url = [NSURL fileURLWithPath:unzipPath];
//        // 创建解压文件夹
//        NSError *pathError = nil;
//        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&pathError];
//        NSLog(@"解压到路径：%@ ",unzipPath);
//        if (pathError){return;}// 如果创建失败则返回
//
//        [SSZipArchive unzipFileAtPath:zipPath toDestination:unzipPath delegate:self];
//
//        success = [SSZipArchive unzipFileAtPath:zipPath toDestination:unzipPath overwrite:YES password:nil  progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
//        } completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
//            if (error) {
//                // 异常
//            } else {
//                // 读取文件夹内容
//            NSError *error = nil;
//            NSMutableArray*items = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:unzipPath
//            error:&error] mutableCopy];
//                if (error) {
//                    return;
//                }
//                [items enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                    NSLog(@"解压出来对象：%lu %@",(unsigned long)idx,obj);
//                    // 仅仅是简单判断，方法不好
//                    if ([obj containsString:@".txt"]) {
//                        NSLog(@"是txt");
//                    }
//                }];
//            }
//        }];
//    }
//
//    return;
}

    
    
#pragma mark -----------------------通知------------------
- (void) emailFileUploadNoti:(NSNotification *) noti
{
    NSArray *results = noti.object;
    if ([results[0] intValue] == 0) { // 成功
        
        EmailNodeModel *nodeM = [[EmailNodeModel alloc] init];
        nodeM.dsKey = self.srcKey;
        nodeM.flags = self.emailInfo.Read;
        nodeM.attchCount = self.emailInfo.attachCount;
        nodeM.subTitle = self.emailInfo.Subject?:@"";
        nodeM.content = self.emailInfo.content.length > 50?[self.emailInfo.content substringWithRange:NSMakeRange(0, 50)]:self.emailInfo.content;
        nodeM.revDate = [NSDate getTimestampFromDate:self.emailInfo.revDate];
        nodeM.fromName = self.emailInfo.fromName?:@"";
        nodeM.fromEmailBox = self.emailInfo.From?:@"";
        
        if (self.emailInfo.toUserArray && self.emailInfo.toUserArray.count > 0) {
             nodeM.toUserJosn = [[EmailUserModel mj_keyValuesArrayWithObjectArray:self.emailInfo.toUserArray] mj_JSONString];
        }
        if (self.emailInfo.ccUserArray && self.emailInfo.ccUserArray.count > 0) {
            nodeM.ccUserJosn = [[EmailUserModel mj_keyValuesArrayWithObjectArray:self.emailInfo.ccUserArray] mj_JSONString];
        }
        if (self.emailInfo.bccUserArray && self.emailInfo.bccUserArray.count > 0) {
            nodeM.bccUserJosn = [[EmailUserModel mj_keyValuesArrayWithObjectArray:self.emailInfo.bccUserArray] mj_JSONString];
        }
        // 模型转string
        NSString *jsonString = nodeM.mj_JSONString;
        // 公钥加密 json
        jsonString = aesEncryptString(jsonString, [self.msgKey substringToIndex:16]);
        
        NSString *messageId = [NSString stringWithFormat:@"%@_%d",self.emailInfo.floderName,self.emailInfo.uid];
        if (self.emailInfo.isGoogleAPI) {
            messageId = [NSString stringWithFormat:@"%@_%@",self.emailInfo.floderName,self.emailInfo.messageid];
        }
        
        [SendRequestUtil sendEmailFileWithFileid:results[1] fileSize:results[2] fileMd5:results[3] mailInfo:jsonString srcKey:self.srcKey uid:messageId  ShowHud:NO];
        
    } else { // 失败
        [AppD.window hideHud];
        [AppD.window showFaieldHudInView:AppD.window hint:@"Failed to Upload"];
    }
}
- (void) emailUploadNodeNoti:(NSNotification *) noti
{
    [AppD.window hideHud];
    NSDictionary *dic = noti.object;
    NSInteger retCode = [dic[@"RetCode"] integerValue];
    if (retCode == 0) {
        _isBakNode = YES;
        [_nodeBtn setImage:[UIImage imageNamed:@"statusbar_download_node_backups"] forState:UIControlStateNormal];
        [AppD.window showSuccessHudInView:AppD.window hint:@"Successed"];
    } else if (retCode == 1) {
        [AppD.window showFaieldHudInView:AppD.window hint:@"This email is backed up."];
    } else {
        [AppD.window showFaieldHudInView:AppD.window hint:@"Failed to Upload."];
    }
}
- (void) emailDelNodeNoti:(NSNotification *) noti
{
    NSDictionary *dic = noti.object;
    NSInteger retCode = [dic[@"RetCode"] integerValue];
    if (retCode == 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:EMIAL_FLAGS_CHANGE_NOTI object:@(3)];
        [self leftNavBarItemPressedWithPop:YES];
    } else {
        [AppD.window showFaieldHudInView:AppD.window hint:@"Failed to Delete"];
    }
}

- (void) checkEmailBakNodeNoti:(NSNotification *) noti
{
    _isBakNode = YES;
    [_nodeBtn setImage:[UIImage imageNamed:@"statusbar_download_node_backups"] forState:UIControlStateNormal];
}

@end
