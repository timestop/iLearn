//
//  QuestionnaireViewController.h
//  iLearn
//
//  Created by Charlie Hung on 2015/7/4.
//  Copyright (c) 2015 intFocus. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QuestionnaireViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSDictionary *questionnaireContent;

@end