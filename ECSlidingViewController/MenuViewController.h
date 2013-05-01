//
//  MenuViewController.h
//  ECSlidingViewController
//
//  Created by Michael Enriquez on 1/23/12.
//  Copyright (c) 2012 EdgeCase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ECSlidingViewController.h"
#import "GTLTasks.h"

@interface MenuViewController : UIViewController <UITableViewDataSource, UITabBarControllerDelegate>

@property (nonatomic,strong) GTLServiceTasks *tasksService;

@end
