//
//  ViewController.h
//  iNotification
//
//  Created by lijunjie on 15/5/25.
//  Copyright (c) 2015年 Intfocus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <JTCalendar/JTCalendar.h>
#import "ListViewController.h"

@interface NotificationViewController : ContentViewController<JTCalendarDataSource, ContentViewProtocal>

@property (weak, nonatomic) IBOutlet JTCalendarMenuView *calendarMenuView;
@property (weak, nonatomic) IBOutlet JTCalendarContentView *calendarContentView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *calendarContentViewHeight;
@property (strong, nonatomic) JTCalendar *calendar;
@property (nonatomic, strong) ListViewController *masterViewController;
@end

