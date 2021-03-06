//
//  ContentViewController.h
//  iLearn
//
//  Created by Charlie Hung on 2015/6/27.
//  Copyright (c) 2015 intFocus. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ContentViewProtocal <NSObject>

- (void)syncData;

@optional
- (void)scanQRCode;
- (void)actionBack:(id)sender;

@end


@class ListViewController;

@interface ContentViewController : UIViewController

@property (weak, nonatomic) ListViewController *listViewController;

@end
