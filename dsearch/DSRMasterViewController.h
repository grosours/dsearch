//
//  DSRMasterViewController.h
//  dsearch
//
//  Created by guillaume faure on 14/01/2014.
//  Copyright (c) 2014 guillaume faure. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSRDetailViewController;

@interface DSRMasterViewController : UITableViewController

@property (strong, nonatomic) DSRDetailViewController *detailViewController;

@end
