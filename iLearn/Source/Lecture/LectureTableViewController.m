//
//  LectureTableViewController.m
//  iLearn
//
//  Created by lijunjie on 15/7/14.
//  Copyright (c) 2015年 intFocus. All rights reserved.
//
#import "LectureTableViewController.h"
#import "DetailViewController.h"
#import "PasswordViewController.h"
#import "QuestionnaireUtil.h"
#import "ExamViewController.h"
#import "LicenseUtil.h"
#import "ExamUtil.h"
#import "FileUtils.h"
#import "HttpUtils.h"
#import "ViewUtils.h"
#import <MBProgressHUD.h>
#import <SSZipArchive.h>
#import "ListViewController.h"
#import "DataHelper.h"
#import "CoursePackage.h"
#import "CoursePackageContent.h"
#import "CoursePackageDetail.h"
#import "CourseWrap.h"
#import "DisplayViewController.h"
#import "LectureTableViewCell.h"
#import "ExtendNSLogFunctionality.h"

static NSString *const kExamVCStoryBoardID = @"ExamViewController";
static NSString *const kShowDetailSegue    = @"showDetailPage";
static NSString *const kShowSettingsSegue  = @"showSettingsPage";

static NSString *const kTableViewCellIdentifier = @"LectureTableViewCell";

@interface LectureTableViewController () <DetailViewControllerProtocol>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) ConnectionManager *connectionManager;

@property (strong, nonatomic) NSArray *dataList;

@property (assign, nonatomic) BOOL hasAutoSynced;
@property (strong, nonatomic) MBProgressHUD *progressHUD;

@property (weak, nonatomic) UIAlertView *lastAlertView;

@property (assign, nonatomic) BOOL showBeginTestInfo;
@property (assign, nonatomic) BOOL showRemoveButton;
@property (nonatomic) ContentTableViewCell *currentCell;

@property (strong, nonatomic) NSNumber *depth;
@property (strong, nonatomic) CoursePackage *lastCoursePackage;
@end


@implementation LectureTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _dataList = [NSArray array];
    
    self.connectionManager = [[ConnectionManager alloc] init];
    _connectionManager.delegate = self;
    _depth = @1; // 一级: 课程包列表， 二级: 课件包、课件、考试、问卷, 三级: 二级内容的重组
    
    NSLog(@"hello world.");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self syncData];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kShowDetailSegue]) {
        DetailViewController *detailVC = (DetailViewController*)segue.destinationViewController;
        detailVC.titleString       = [sender name];
        detailVC.descString        = [sender desc];
        detailVC.delegate          = self;
        detailVC.showFromBeginTest = self.showBeginTestInfo;
        detailVC.showRemoveButton  = self.showRemoveButton;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_dataList count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    LectureTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTableViewCellIdentifier];
    cell.delegate = self;

    cell.statusTitleLabel.text = @"类型: ";
    cell.scoreTitleLabel.text  = @"状态: ";
    
    switch ([self.depth intValue]) {
        case 1: {
            CoursePackage *coursePackage = [self.dataList objectAtIndex:indexPath.row];
            cell.titleLabel.text        = coursePackage.name;
            cell.statusLabel.text       = @"课程包";
            cell.scoreTitleLabel.hidden = YES;
            cell.scoreLabel.hidden      = YES;
            [cell.actionButton setTitle:@"进入" forState:UIControlStateNormal];
            [cell.infoButton setImage:[UIImage imageNamed:@"course_package"] forState:UIControlStateNormal];
            
            break;
        }
        case 2:
        case 3: {
            id obj =  [self.dataList objectAtIndex:indexPath.row];
            NSArray *statusLabelText    = [obj statusLabelText];
            cell.titleLabel.text        = [obj name];
            cell.statusLabel.text       = [obj typeName];
            cell.scoreLabel.text        = statusLabelText[0];
            cell.scoreTitleLabel.hidden = [[statusLabelText[0] uppercaseString] isEqualToString:@"TODO"];
            cell.scoreLabel.hidden      = [[statusLabelText[0] uppercaseString] isEqualToString:@"TODO"];
            [cell.actionButton setTitle:statusLabelText[1] forState:UIControlStateNormal];
            [cell.infoButton setImage:[UIImage imageNamed:[obj infoButtonImage]] forState:UIControlStateNormal];
            
            break;
        }
        default:
            break;
    }
    return cell;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 120.0;
}

- (void)didSelectInfoButtonOfCell:(ContentTableViewCell*)cell {
    self.currentCell = cell;
    self.showBeginTestInfo = NO;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    id obj = [self.dataList objectAtIndex:[indexPath row]];
    self.showRemoveButton  = [obj canRemove];
    [self performSegueWithIdentifier:kShowDetailSegue sender:obj];
}

- (void)didSelectActionButtonOfCell:(ContentTableViewCell*)cell {
    self.currentCell = cell;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    self.progressHUD.labelText = NSLocalizedString(@"LIST_SYNCING", nil);
    
    BOOL removeHUD = YES;
    NSInteger depth = [self.depth intValue];
    id obj = [self.dataList objectAtIndex:indexPath.row];
    switch (depth) {
        case 1: {
            [self depthPlus];
            CoursePackage *coursePackage = (CoursePackage *)obj;
            _dataList = [DataHelper coursePackageContent:NO pid:coursePackage.ID];
            self.listViewController.titleLabel.hidden = YES;
            self.listViewController.backButton.hidden = NO;
            self.listViewController.courseNameLabel.hidden = NO;
            self.listViewController.courseNameLabel.text = coursePackage.name;
            self.lastCoursePackage = coursePackage;
            [self.tableView reloadData];
            break;
        }
        case 2:
        case 3: {
            if([obj isCourseWrap]) {
                [self depthPlus];
                CourseWrap *courseWrap = (CourseWrap *)obj;
                _dataList = courseWrap.courseList;
                [self.tableView reloadData];
                self.listViewController.courseNameLabel.text = courseWrap.name;
            }
            else {
                LectureTableViewCell *lectureTableViewCell = (LectureTableViewCell *)cell;
                NSString *btnLabel = lectureTableViewCell.actionButton.titleLabel.text;
                
                CoursePackageDetail *packageDetail = (CoursePackageDetail *)obj;
                if([packageDetail isCourse]) {
                    if([btnLabel isEqualToString:@"下载"]) {
                        if([HttpUtils isNetworkAvailable]) {
                            self.progressHUD.labelText = @"下载中...";
                            removeHUD = NO;
                            [self.connectionManager downloadCourse:packageDetail.courseId Ext:packageDetail.courseExt];
                        }
                        else {
                            [self.progressHUD removeFromSuperview];
                            [ViewUtils showPopupView:self.listViewController.view Info:@"无网络，不下载"];
                        }
                    }
                    else {
                        DisplayViewController *displayViewController = [[DisplayViewController alloc] init];
                        displayViewController.packageDetail = packageDetail;
                        [self presentViewController:displayViewController animated:YES completion:nil];
                    }
                }
                else if([packageDetail isExam]) {
                    if([packageDetail isExamDownload]) {
                        if([btnLabel isEqualToString:@"查看结果"]) {
                            [self begin];
                        }
                        else {
                            self.showBeginTestInfo = YES;
                            self.showRemoveButton  = NO;
                            [self performSegueWithIdentifier:kShowDetailSegue sender:packageDetail];
                        }
                    }
                    else {
                        if([HttpUtils isNetworkAvailable]) {
                            self.progressHUD.labelText = @"下载中...";
                            removeHUD = NO;
                            [_connectionManager downloadExamWithId:packageDetail.examId];
                        }
                        else {
                            [_progressHUD hide:YES];
                            [ViewUtils showPopupView:self.listViewController.view Info:@"无网络，不下载"];
                        }
                    }
                }
            }
            break;
        }
        default:
            break;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if([HttpUtils isNetworkAvailable]) {
            switch (depth) {
                case 1: {
                    CoursePackage *coursePackage = (CoursePackage *)obj;
                    NSArray *array = [NSArray array];
                    array = [DataHelper coursePackageContent:YES pid:coursePackage.ID];
                    self.listViewController.courseNameLabel.text = coursePackage.name;
                    self.lastCoursePackage = coursePackage;
                    if([array count]) {
                        _dataList = array;
                        [self.tableView reloadData];
                    }
                    break;
                }
                default:
                    break;
            }
        }
        
        if(removeHUD) {
            [_progressHUD hide:YES];
        }
    });
    NSLog(@"enter - depth: %@", self.depth);
}

- (IBAction)actionBack:(id)sender {

    [sender setEnabled:NO];
    
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    self.progressHUD.labelText = NSLocalizedString(@"LIST_SYNCING", nil);
    
    NSInteger depth = [self.depth intValue];
    
    if(depth == 2) {
        [_progressHUD hide:YES];
        [sender setEnabled:YES];
        
        [self reloadSelf];
        
        return;
    }
    else if(depth == 3) {
        _dataList = [DataHelper coursePackageContent:NO pid:self.lastCoursePackage.ID];
        self.listViewController.courseNameLabel.hidden = NO;
        self.listViewController.courseNameLabel.text   = self.lastCoursePackage.name;
        [self.tableView reloadData];
        [self depthMinus];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if([HttpUtils isNetworkAvailable]) {
            if(depth == 3) {
                NSArray *array = [DataHelper coursePackageContent:YES pid:self.lastCoursePackage.ID];
                if([array count] > 0) {
                    _dataList = array;
                    [self.tableView reloadData];
                }
            
            }
        }
        [_progressHUD hide:YES];
    });
    
    [sender setEnabled:YES];
    NSLog(@"back - depth: %@", self.depth);
}
- (void)didSelectQRCodeButtonOfCell:(ContentTableViewCell*)cell {}

#pragma mark - IBAction

- (void)enterExamPageForContent:(NSDictionary*)content {
    __weak LectureTableViewController *weakSelf = self;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    hud.labelText = NSLocalizedString(@"LIST_LOADING", nil);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *examDBPath = [FileUtils coursePath:content[CommonFileName] Ext:@"db"];
        [ExamUtil parseContentIntoDB:content Path:examDBPath];
        
        NSDictionary *dbContent = [ExamUtil contentFromDBFile:examDBPath];
        [dbContent setValue:examDBPath forKey:CommonDBPath];
        [dbContent setValue:[NSNumber numberWithInt:ExamTypesPractice] forKey:ExamType];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hide:YES];
            
            UIStoryboard *storyboard   = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            ExamViewController *examVC = (ExamViewController *)[storyboard instantiateViewControllerWithIdentifier:kExamVCStoryBoardID];
            examVC.examContent         = dbContent;
            [weakSelf presentViewController:examVC animated:YES completion:^{
                NSLog(@"popup view.");
            }];
        });
    });
}

#pragma mark - ConnectionManagerDelegate

- (void)connectionManagerDidDownloadCourse:(NSString *)courseID Ext:(NSString *)extName withError:(NSError *)error {
    [_progressHUD hide:YES];
    
    if(!error) {
        if([extName isEqualToString:@"zip"]) {
            NSString *zipPath    = [FileUtils coursePath:courseID Ext:extName UseExt:YES];
            NSString *coursePath = [FileUtils coursePath:courseID Ext:extName UseExt:NO];
            if([SSZipArchive unzipFileAtPath:zipPath toDestination:coursePath]) {
                NSFileManager *fileManage = [NSFileManager defaultManager];
                NSArray *files = [fileManage subpathsAtPath: coursePath];
                
                NSString *subDirPath = [coursePath stringByAppendingPathComponent:files[0]];
                NSString *tmpPath = [NSString stringWithFormat:@"%@-tmp", coursePath];
                [fileManage moveItemAtPath:subDirPath toPath:tmpPath error:&error];
                NSErrorPrint(error, @"move %@ => %@", subDirPath, tmpPath);
                [FileUtils removeFile:coursePath];
                [fileManage moveItemAtPath:tmpPath toPath:coursePath error:&error];
                NSErrorPrint(error, @"move %@ => %@", tmpPath, coursePath);
                
                [FileUtils removeFile:zipPath];
            }
        }
        NSIndexPath *indexPath = [self.tableView indexPathForCell:self.currentCell];
        [self.tableView beginUpdates];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }
    else {
        [ViewUtils showPopupView:self.listViewController.view Info:[error localizedDescription]];
    }
}
- (void)connectionManagerDidDownloadExamsForUser:(NSString *)userId withError:(NSError *)error {
    [_progressHUD hide:YES];
    
    if (error) {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
}

- (void)connectionManagerDidDownloadExam:(NSString *)examId withError:(NSError *)error {
    [_progressHUD hide:YES];
    
    if(!error) {
        NSString *examPath = [ExamUtil examPath:examId];
        NSString *coursePath = [FileUtils coursePath:examId Ext:[examPath pathExtension]];
        [FileUtils move:examPath to:coursePath];
        
        [self.tableView reloadData];
    }
    else {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
}

- (void)connectionManagerDidUploadExamResult:(NSString *)examId withError:(NSError *)error {
    
    [_progressHUD hide:YES];
    
    if (!error) {
        NSString *dbPath = [ExamUtil examDBPath:examId];
        [ExamUtil setExamSubmittedwithDBPath:dbPath];
    }
    else {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
}

- (void)connectionManagerDidUploadExamScannedResult:(NSString *)result withError:(NSError *)error {
    [_progressHUD hide:YES];
}

- (void)syncData {
    @try {
        [self syncDataCoreCode];
    }
    @catch (NSException *exception) {
        [self.progressHUD removeFromSuperview];
        
        [ViewUtils showPopupView:self.listViewController.view Info:[exception description]];
        
        [self reloadSelf];
    }
    @finally {
    }
}

- (void)syncDataCoreCode {
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    self.progressHUD.labelText = NSLocalizedString(@"LIST_SYNCING", nil);
    
    switch ([self.depth intValue]) {
        case 1: {
            _dataList = [DataHelper coursePackages:NO];
            self.listViewController.backButton.hidden      = YES;
            self.listViewController.titleLabel.hidden      = NO;
            self.listViewController.courseNameLabel.hidden = YES;
            
            break;
        }
        case 2: {
            _dataList = [DataHelper coursePackageContent:NO pid:self.lastCoursePackage.ID];
            self.listViewController.courseNameLabel.hidden = NO;
            self.listViewController.courseNameLabel.text   = self.lastCoursePackage.name;
            
            break;
        }
        default:
            break;
    }
    [self.tableView reloadData];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if([HttpUtils isNetworkAvailable]) {
            NSArray *array = [NSArray array];
            switch ([self.depth intValue]) {
                case 1: {
                    array = [DataHelper coursePackages:YES];
                    break;
                }
                case 2: {
                    array = [DataHelper coursePackageContent:YES pid:self.lastCoursePackage.ID];
                    break;
                }
                default:
                    break;
            }
            if([array count] > 0) {
                _dataList = array;
                [self.tableView reloadData];
            }
        }
        [_progressHUD hide:YES];
    });
}


#pragma mark - DetailViewControllerProtocol
- (void)begin {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:self.currentCell];
    CoursePackageDetail *packageDetail = [self.dataList objectAtIndex:indexPath.row];
    NSMutableDictionary *content = [NSMutableDictionary dictionaryWithDictionary:packageDetail.examDictContent];
    content[CommonFileName] = packageDetail.examId;
    
    [self enterExamPageForContent:[NSDictionary dictionaryWithDictionary:content]];
}

- (void)removeCourse {
    NSIndexPath *indexPath = [self.tableView indexPathForCell:self.currentCell];
    CoursePackageDetail *course = (CoursePackageDetail*)[self.dataList objectAtIndex:indexPath.row];
    
    if([course isExam]) {
        [FileUtils removeFile:[FileUtils coursePath:course.examId Ext:@"json"]];
        [FileUtils removeFile:[FileUtils coursePath:course.examId Ext:@"db"]];
    }
    else {
        [ViewUtils showPopupView:self.listViewController.view Info:@"删除中..." while:^{
            [FileUtils removeFile:[FileUtils coursePath:course.courseId Ext:course.courseExt]];
            [FileUtils removeFile:[FileUtils courseProgressPath:course.courseId Ext:course.courseExt]];
        }];
    }

    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

#pragma mark - asisstant methods

- (void)depthPlus {
    NSInteger depth = [self.depth intValue];
    depth = depth + 1;
    if(depth > 3) {
        depth = 3;
    }
    self.depth = [NSNumber numberWithInteger:depth];
}

- (void)depthMinus {
    NSInteger depth = [self.depth intValue];
    depth = depth - 1;
    if(depth < 1) {
        depth = 1;
    }
    self.depth = [NSNumber numberWithInteger:depth];
}

- (void)reloadSelf {
    self.listViewController.listType = ListViewTypeLecture;
    [self.listViewController refreshContentView];
}

@end
