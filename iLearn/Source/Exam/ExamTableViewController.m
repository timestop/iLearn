//
//  ExamTableViewController.m
//  iLearn
//
//  Created by Charlie Hung on 2015/6/26.
//  Copyright (c) 2015 intFocus. All rights reserved.
//

#import "ExamTableViewController.h"
#import "DetailViewController.h"
#import "PasswordViewController.h"
#import "ExamViewController.h"
#import "ScoreQRCodeViewController.h"
#import "LicenseUtil.h"
#import "ExamUtil.h"
#import "ViewUtils.h"
#import "UIImage+MDQRCode.h"
#import <MBProgressHUD.h>
#import "ListViewController.h"

static NSString *const kShowSubjectSegue = @"showSubjectPage";
static NSString *const kShowDetailSegue = @"showDetailPage";
static NSString *const kShowPasswordSegue = @"showPasswordPage";
static NSString *const kShowScoreQRCode = @"showScoreQRCode";

static NSString *const kExamTableViewCellIdentifier = @"ExamTableViewCell";

static const NSInteger kMinScanInterval = 3;

@interface ExamTableViewController () <DetailViewControllerProtocol>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) ConnectionManager *connectionManager;

@property (strong, nonatomic) NSArray *contents;

@property (assign, nonatomic) BOOL hasAutoSynced;
@property (strong, nonatomic) MBProgressHUD *progressHUD;

@property (strong, nonatomic) NSMutableArray *unsubmittedExamResults;
@property (strong, nonatomic) NSMutableArray *unsubmittedExamScannedResults;

@property (strong, nonatomic) NSString *lastScannedResult;
@property (assign, nonatomic) long long lastScanDate;
@property (weak, nonatomic) UIAlertView *lastAlertView;

@property (assign, nonatomic) BOOL showBeginTestInfo;
@property (nonatomic) ContentTableViewCell *currentCell;

@end


@implementation ExamTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.connectionManager = [[ConnectionManager alloc] init];
    _connectionManager.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self refreshContent];
    
    if (!_hasAutoSynced) {
        _hasAutoSynced = YES;
        [self syncData];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:kShowDetailSegue]) {
        
        DetailViewController *detailVC = (DetailViewController*)segue.destinationViewController;
        detailVC.titleString = [[ExamUtil titleFromContent:sender] stringByAppendingString:NSLocalizedString(@"LIST_DETAIL", nil)];
        detailVC.descString = [ExamUtil descFromContent:sender];
        if (self.showBeginTestInfo) {
            detailVC.delegate = self;
            detailVC.showFromBeginTest = self.showBeginTestInfo;
        }
        else {
            detailVC.showFromBeginTest = self.showBeginTestInfo;
        }
        
    }
    else if ([segue.identifier isEqualToString:kShowPasswordSegue]) {

        PasswordViewController *detailVC = (PasswordViewController*)segue.destinationViewController;
        
        detailVC.titleString = [[ExamUtil titleFromContent:sender] stringByAppendingString:NSLocalizedString(@"LIST_DETAIL", nil)];
        detailVC.descString = [ExamUtil descFromContent:sender];
        detailVC.password = sender[ExamPassword];
        __weak id weakSelf = self;
        detailVC.callback = ^(void){
            [weakSelf enterExamPageForContent:sender];
        };
    }
    else if ([segue.identifier isEqualToString:kShowSubjectSegue]) {

        UIViewController *viewController = segue.destinationViewController;
        
        if ([viewController isKindOfClass:[ExamViewController class]]) {
            ExamViewController *subjectVC = (ExamViewController*)viewController;
            subjectVC.examContent = sender;
        }
    }
    else if ([segue.identifier isEqualToString:kShowScoreQRCode]) {
        
        ScoreQRCodeViewController *scoreQRCodeVC = segue.destinationViewController;
        scoreQRCodeVC.scoreQRCodeImage = sender;
    }
}

#pragma mark - UI Adjustment

- (void)syncData
{
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    _progressHUD.labelText = NSLocalizedString(@"LIST_SYNCING", nil);
    
    self.unsubmittedExamResults = [[ExamUtil resultFiles] mutableCopy];
    self.unsubmittedExamScannedResults = [[ExamUtil unsubmittedScannedResults] mutableCopy];
    
    [self downloadExams];
    [self syncExamResults];
    [self syncScannedExamResults];
}

- (void)syncExamResults
{
    NSString *filePath = [_unsubmittedExamResults firstObject];
    
    if (filePath) {
        [_unsubmittedExamResults removeObjectAtIndex:0];
        [_connectionManager uploadExamResultWithPath:filePath];
    }
}

- (void)syncScannedExamResults
{
    NSString *scannedResult = [_unsubmittedExamScannedResults firstObject];
    
    if (scannedResult) {
        [_unsubmittedExamScannedResults removeObjectAtIndex:0];
        [_connectionManager uploadExamScannedResult:scannedResult];
    }
}

- (void)downloadExams
{
    [_connectionManager downloadExamsForUser:[LicenseUtil userId]];
}

- (void)downloadExamId:(NSString*)examId
{
    self.progressHUD = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    _progressHUD.labelText = NSLocalizedString(@"LIST_SYNCING", nil);
    [_connectionManager downloadExamWithId:examId];
}

- (void)refreshContent
{
    self.contents = [ExamUtil loadExams];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_contents count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self tableView:tableView cellForExamRowAtIndexPath:indexPath];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForExamRowAtIndexPath:(NSIndexPath *)indexPath
{
    ExamTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kExamTableViewCellIdentifier];
    cell.delegate = self;
    
    NSDictionary *content = [_contents objectAtIndex:indexPath.row];
    
    cell.titleLabel.text = [ExamUtil titleFromContent:content];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY/MM/dd"];
    long long epochTime = [ExamUtil endDateFromContent:content];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:epochTime];
    NSString *endDateString = [formatter stringFromDate:endDate];
    
    cell.expirationDateLabel.text = [NSString stringWithFormat:NSLocalizedString(@"LIST_END_DATE_TEMPLATE", nil), endDateString];
    
    cell.scoreTitleLabel.hidden = YES;
    cell.scoreLabel.hidden = YES;
    cell.qrCodeButton.hidden = YES;
    cell.actionButton.enabled = YES;
    
    if ([content[ExamCached] isEqualToNumber:@1]) {
        
        NSDate *now = [NSDate date];
        NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[ExamUtil startDateFromContent:content]];
        NSInteger scoreInt = -1;
        ExamTypes examType = [content[ExamType] integerValue];
        
        NSDate *examStartDate = nil;
        NSDate *examEndDate = nil;
        
        if (content[ExamExamStart]) {
            examStartDate = [NSDate dateWithTimeIntervalSince1970:[content[ExamExamStart] longLongValue]];
        }
        
        if (content[ExamExamEnd]) {
            examEndDate = [NSDate dateWithTimeIntervalSince1970:[content[ExamExamEnd] longLongValue]];
            
            if ([examEndDate laterDate:now] == now && examType == ExamTypesFormal) { // Exam was started but ended now
                
                NSNumber *score = content[ExamScore];
                
                if (score == nil || [score isEqualToNumber:@(-1)]) { // Not calculated score yet
                    NSString *fileName = content[CommonFileName];
                    NSString *dbPath = [ExamUtil examDBPath:fileName];
                    
                    scoreInt = [ExamUtil examScoreOfDBPath:dbPath];
                    
                    NSInteger qualityLine = [content[ExamQualify] integerValue];
                    NSInteger allowTimes = [content[ExamAllowTimes] integerValue];
                    NSInteger submitTimes = [content[ExamSubmitTimes] integerValue];
                    NSInteger newSubmitTimes = submitTimes + 1;
                    
                    [ExamUtil updateSubmitTimes:newSubmitTimes ofDBPath:dbPath];
                    
                    ExamTypes examType = [content[ExamType] integerValue];
                    
                    if (examType == ExamTypesFormal &&
                        scoreInt < qualityLine &&
                        newSubmitTimes < allowTimes)
                    { // Should test again
                        
                        [ExamUtil resetExamStatusOfDBPath:dbPath];
                        scoreInt = -1;
                        examStartDate = nil;
                    }
                    else {
                        if (newSubmitTimes > 1) { // Has submitted, the score should be just qualified
                            scoreInt = qualityLine;
                            [ExamUtil updateExamScore:scoreInt ofDBPath:dbPath];
                        }
                        [ExamUtil generateUploadJsonFromDBPath:dbPath];
                    }

                }
            }
        }
        
        
        if ([startDate laterDate:now] == startDate) { // Exam is not started yet
            cell.statusLabel.text = NSLocalizedString(@"LIST_STATUS_NOT_STARTED", nil);
            [cell.actionButton setTitle:NSLocalizedString(@"LIST_STATUS_NOT_STARTED", nil) forState:UIControlStateNormal];
            cell.actionButtonType = ContentTableViewCellActionView;
            cell.actionButton.enabled = NO;
        }
        else if ([endDate laterDate:now] == now && examStartDate == nil) { // Exam is ended and not start answering
            cell.statusLabel.text = NSLocalizedString(@"LIST_STATUS_ENDED", nil);
            [cell.actionButton setTitle:NSLocalizedString(@"LIST_BUTTON_ENDED", nil) forState:UIControlStateNormal];
            cell.actionButton.enabled = NO;
        }
        else { // Exam is started
            NSNumber *score;
            
            if (scoreInt == -1) {
                score = content[ExamScore];
            }
            else {
                score = @(scoreInt);
            }
            
            if (score != nil && [score integerValue] != -1) {
                // Score was calculated, test was submitted but may not success
                
                NSNumber *submitted = content[ExamSubmitted];
                
                if ([submitted isEqualToNumber:@1]) {
                    cell.statusLabel.text = NSLocalizedString(@"LIST_STATUS_SUBMITTED", nil);
                }
                else {
                    NSMutableAttributedString *statusLabelString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"LIST_STATUS_NOT_SUBMITTED", nil)];
                    NSRange statusLabelRange = {0,[statusLabelString length]};
                    [statusLabelString addAttributes:@{NSForegroundColorAttributeName: ILDarkRed} range:statusLabelRange];
                    cell.statusLabel.attributedText = statusLabelString;
                    cell.qrCodeButton.hidden = NO;
                }
                [cell.actionButton setTitle:NSLocalizedString(@"LIST_BUTTON_VIEW_RESULT", nil) forState:UIControlStateNormal];
                cell.actionButtonType = ContentTableViewCellActionView;
                
                cell.scoreTitleLabel.hidden = NO;
                cell.scoreLabel.hidden = NO;
                
                cell.scoreTitleLabel.text = NSLocalizedString(@"LIST_SCORE_TITLE", nil);
                
                NSString *strScore = [NSString stringWithFormat:@"%lld", [score longLongValue]];
                NSString *scoreString = [NSString stringWithFormat:NSLocalizedString(@"LIST_SCORE_TEMPLATE", nil), [score longLongValue]];
                NSMutableAttributedString *scoreAttrString = [[NSMutableAttributedString alloc] initWithString:scoreString];
                [scoreAttrString addAttributes:@{NSForegroundColorAttributeName:[UIColor blackColor]} range:NSMakeRange(0, [scoreString length])];
                NSRange scoreRange = [scoreString rangeOfString:strScore];
                [scoreAttrString addAttributes:@{NSForegroundColorAttributeName: ILDarkRed} range:scoreRange];
                cell.scoreLabel.attributedText = scoreAttrString;
                
                cell.qrCodeButton.titleLabel.text = NSLocalizedString(@"LIST_BUTTON_QRCODE", nil);
            }
            else {
                // Not start testing or testing
                cell.statusLabel.text = NSLocalizedString(@"LIST_STATUS_TESTING", nil);
                [cell.actionButton setTitle:NSLocalizedString(@"LIST_BUTTON_START_TESTING", nil) forState:UIControlStateNormal];
                cell.actionButtonType = ContentTableViewCellActionView;
            }
            
        }
    }
    else {
        
        NSDate *now = [NSDate date];
        
        if ([endDate laterDate:now] == now) { // Exam is ended
            cell.statusLabel.text = NSLocalizedString(@"LIST_STATUS_ENDED", nil);
            [cell.actionButton setTitle:NSLocalizedString(@"LIST_BUTTON_ENDED", nil) forState:UIControlStateNormal];
            cell.actionButton.enabled = NO;
        }
        else {
            cell.statusLabel.text = NSLocalizedString(@"LIST_STATUS_NOT_DOWNLOADED", nil);
            [cell.actionButton setTitle:NSLocalizedString(@"LIST_BUTTON_DOWNLOAD", nil) forState:UIControlStateNormal];
            cell.actionButtonType = ContentTableViewCellActionDownload;
        }
    }
    
    return cell;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 120.0;
}

- (void)didSelectInfoButtonOfCell:(ContentTableViewCell*)cell
{
    self.showBeginTestInfo = NO;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSDictionary *content = [_contents objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:kShowDetailSegue sender:content];
}

- (void)didSelectActionButtonOfCell:(ContentTableViewCell*)cell
{
    self.showBeginTestInfo = YES;
    self.currentCell = cell;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NSDictionary *content = [_contents objectAtIndex:indexPath.row];
    
    if (cell.actionButtonType == ContentTableViewCellActionDownload) {
        
        NSString *examId = [NSString stringWithFormat:@"%@", content[ExamId]];
        [self downloadExamId:examId];
    }
    else if (cell.actionButtonType == ContentTableViewCellActionView) {
        
        ExamTableViewCell *examTVC = (ExamTableViewCell *)cell;
        if ([examTVC.actionButton.titleLabel.text isEqual:NSLocalizedString(@"LIST_BUTTON_VIEW_RESULT", nil)]) {
            [self beginTest: content];
        }
        else {
            [self performSegueWithIdentifier:kShowDetailSegue sender:content];
        }
    }
}

- (void)didSelectQRCodeButtonOfCell:(ContentTableViewCell*)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    NSLog(@"didSelectQRCodeButtonOfCell:");
    NSLog(@"indexPath.row: %ld", (long)indexPath.row);
    
    NSDictionary *content = [_contents objectAtIndex:indexPath.row];
    
    NSString *examId = content[ExamId];
    NSNumber *examScore = content[ExamScore];
    NSString *userId = [LicenseUtil userId];
    
    NSString *qrCodeString = [NSString stringWithFormat:@"iLearn+%@+%@+%@", userId, examId, examScore];
    UIImage *qrCodeImage = [UIImage mdQRCodeForString:qrCodeString size:200.0];
    
    [self performSegueWithIdentifier:kShowScoreQRCode sender:qrCodeImage];
}

#pragma mark - IBAction

- (void)scanQRCode {
    if ([QRCodeReader supportsMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]]) {
        static QRCodeReaderViewController *reader = nil;
        static dispatch_once_t onceToken;
        
        dispatch_once(&onceToken, ^{
            reader = [[QRCodeReaderViewController alloc] initWithCancelButtonTitle:NSLocalizedString(@"COMMON_CLOSE", nil)];
            reader.modalPresentationStyle = UIModalPresentationFormSheet;
        });
        reader.delegate = self;
        
        [self presentViewController:reader animated:YES completion:NULL];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Reader not supported by the current device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alert show];
    }
}

- (void)enterExamPageForContent:(NSDictionary*)content
{
    __weak ExamTableViewController *weakSelf = self;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.listViewController.view animated:YES];
    hud.labelText = NSLocalizedString(@"LIST_LOADING", nil);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSString *dbPath = [ExamUtil examDBPath:content[CommonFileName]];
        [ExamUtil parseContentIntoDB:content Path:dbPath];
        
        NSDictionary *dbContent = [ExamUtil contentFromDBFile:dbPath];
        [dbContent setValue:dbPath forKey:CommonDBPath];
        //NSLog(@"dbContent: %@", [ExamUtil jsonStringOfContent:dbContent]);

        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hide:YES];
            [weakSelf performSegueWithIdentifier:kShowSubjectSegue sender:dbContent];
        });
    });
}

#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result
{
    NSDate *now = [NSDate date];
    NSTimeInterval nowInterval = [now timeIntervalSince1970];
    
    if (nowInterval - _lastScanDate < kMinScanInterval) {
        return;
    }
    
    _lastScanDate = nowInterval;
    
    if ([_lastScannedResult isEqualToString:result]) {
        
        if (_lastAlertView) {
            [_lastAlertView dismissWithClickedButtonIndex:0 animated:YES];
        }
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"LIST_SCORE_SCANNED_TITLE", nil) message:NSLocalizedString(@"LIST_SCORE_SCANNED_MESSAGE", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"COMMON_CLOSE", nil) otherButtonTitles:nil];
        self.lastAlertView = alert;
        [alert show];
        return;
    }
    
    self.lastScannedResult = result;
    
    NSArray *components = [result componentsSeparatedByString:@"+"];
    
    if ([components count] != 4 || ![components[0] isEqualToString:@"iLearn"]) {
        return;
    }
    
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"LIST_SCORE_SCAN_RESULT_TEMPLATE", nil), components[1], components[2], components[3]];
    
    if (_lastAlertView) {
        [_lastAlertView dismissWithClickedButtonIndex:0 animated:YES];
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"LIST_SCORE_SCAN_RESULT", nil) message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"COMMON_CLOSE", nil) otherButtonTitles:nil];
    self.lastAlertView = alert;
    [alert show];
    
    NSString *savedResult = [@[components[1], components[2], components[3]] componentsJoinedByString:@"+"];
    
    [ExamUtil saveScannedResultIntoDB:savedResult];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ConnectionManagerDelegate

- (void)connectionManagerDidDownloadExamsForUser:(NSString *)userId withError:(NSError *)error
{
    [_progressHUD hide:YES];
    
    if (!error) {
        [self refreshContent];
    }
    else {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
}

- (void)connectionManagerDidDownloadExam:(NSString *)examId withError:(NSError *)error
{
    [_progressHUD hide:YES];
    
    if (!error) {
        [self refreshContent];
    }
    else {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
}

- (void)connectionManagerDidUploadExamResult:(NSString *)examId withError:(NSError *)error
{
    if (!error) {
        NSString *dbPath = [ExamUtil examDBPath:examId];
        [ExamUtil setExamSubmittedwithDBPath:dbPath];
        
        [self refreshContent];
    }
    else {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
    [self syncExamResults];
}

- (void)connectionManagerDidUploadExamScannedResult:(NSString *)result withError:(NSError *)error
{
    if (!error) {
        [ExamUtil setScannedResultSubmitted:result];
    }
    else {
        [ViewUtils showPopupView:self.view Info:[error localizedDescription]];
    }
    [self syncScannedExamResults];
    
}

- (void)beginTest:(NSDictionary *)content {
    NSNumber *examType = content[ExamType];
    NSNumber *examLocation = content[ExamLocation];
    NSNumber *examOpened = content[ExamOpened];
    
    if ([examType isEqualToNumber:@(ExamTypesFormal)] &&
        [examLocation isEqualToNumber:@(ExamLocationsOnsite)] &&
        ![examOpened isEqualToNumber:@1]) {
        
        [self performSegueWithIdentifier:kShowPasswordSegue sender:content];
    }
    else {
        [self enterExamPageForContent:content];
    }
}

#pragma mark - DetailViewControllerProtocol
- (void)begin{
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:self.currentCell];
    NSDictionary *content = [_contents objectAtIndex:indexPath.row];
    [self beginTest:content];
}

@end
