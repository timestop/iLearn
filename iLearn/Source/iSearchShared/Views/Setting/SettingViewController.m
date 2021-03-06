//
//  SettingViewController.m
//  iSearch
//
//  Created by lijunjie on 15/6/25.
//  Copyright (c) 2015年 Intfocus. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SettingViewController.h"
#import "User.h"
#import "LoginViewController.h"
#import "DashboardViewController.h"
#import "SettingDataInfo.h"
#import "ViewUpgrade.h"

typedef NS_ENUM(NSInteger, SettingSectionIndex) {
    SettingUserInfoIndex = 0,
    SettingAppInfoIndex  = 1,
    SettingUpgradeIndex  = 2,
    SettingRegularIndex  = 3
};

@interface SettingViewController()<UITableViewDelegate, UITableViewDataSource, ViewUpgradeProtocol, ViewUpgradeProtocol>

@property (nonatomic, nonatomic) IBOutlet UIButton *btnLogout;
@property (nonatomic, strong) NSMutableArray *dataList;
@property (nonatomic, strong) User *user;

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /*
     *  实例变量初始化
     */
    self.dataList = [[NSMutableArray alloc] init];
    self.user     = [[User alloc] init];
    
    NSDictionary *localVersionInfo =[[NSBundle mainBundle] infoDictionary];
    [self.dataList addObject:@[@"用户名称", self.user.name]];
    [self.dataList addObject:@[@"应用名称", localVersionInfo[@"CFBundleExecutable"]]];
    [self.dataList addObject:@[@"版本更新", @""]];
    /**
     *  控件事件
     */
    UIBarButtonItem *navBtnClose = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(actionBtnClose:)];
    self.navigationItem.rightBarButtonItem = navBtnClose;
    self.navigationItem.title = @"设置";
}

#pragma mark - controls action
- (IBAction)actionBtnClose:(UIBarButtonItem *)sender {
    if([self.delegate respondsToSelector:@selector(dismissSettingView)]) {
        [self.delegate dismissSettingView];
    }
}

- (IBAction)actionLogout:(id)sender {
    LoginViewController *login = [[LoginViewController alloc] initWithNibName:nil bundle:nil];
    UIWindow *window = self.view.window;
    window.rootViewController = login;
}


#pragma mark - <UITableViewDelegate, UITableViewDataSource>
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataList count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"cellID";
    UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    NSArray *array            = self.dataList[indexPath.row];
    cell.textLabel.text       = array[0];
    cell.detailTextLabel.text = array[1];
    
    cell.accessoryType  = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    switch ([indexPath row]) {
        case SettingUserInfoIndex:
        case SettingAppInfoIndex: {
            SettingDataInfo *viewController = [[SettingDataInfo alloc] init];
            viewController.indexRow = indexPath.row;
            [self.navigationController pushViewController:viewController animated:YES];
        }
            break;
        case SettingUpgradeIndex:{
            ViewUpgrade *viewController = [[ViewUpgrade alloc] init];
            viewController.settingViewController = self;
            viewController.delegate = (id)self;
            [self.navigationController pushViewController:viewController animated:YES];
        }
            break;
        default:
            break;
    }
}

#pragma mark - ViewUpgradeProtocol
- (void)dismissViewUpgrade {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
