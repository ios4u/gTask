//
//  TaskListViewController.m
//  gTask
//
//  Created by LIANGJUN JIANG on 3/22/13.
//
//

#import "TaskListViewController.h"
#import "TaskTasksViewController.h"
#import "SVProgressHUD.h"
#import "AppDelegate.h"
#import "LoginViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "MenuViewController.h"

@interface TaskListViewController ()<UIActionSheetDelegate>
{
    UIBarButtonItem *addTaskListButton_;
    UIBarButtonItem *renameTaskListButton_;
    UIBarButtonItem *deleteTaskListButton_;
    NSIndexPath *selectedIndexPath_;

    
}
@property (strong) GTLTasksTaskLists *taskLists;
@property (strong) GTLServiceTicket *taskListsTicket;
@property (strong) NSError *taskListsFetchError;

@property (strong) GTLServiceTicket *editTaskListTicket;

@property (strong) GTLTasksTasks *tasks;
@property (strong) GTLServiceTicket *tasksTicket;
@property (strong) NSError *tasksFetchError;

@property (strong) GTLServiceTicket *editTaskTicket;
@property (strong)  NSIndexPath *selectedIndexPath;
@end

// Constants that ought to be defined by the API


@implementation TaskListViewController
@synthesize tasksService, selectedIndexPath;
@synthesize navBar;

#pragma mark - alert helper
- (void)displayAlertWithMessage:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"gTask"
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}


- (void)displayAlert:(NSString *)title format:(NSString *)format, ... {
    NSString *result = format;
    if (format) {
        va_list argList;
        va_start(argList, format);
        result = [[NSString alloc] initWithFormat:format
                                        arguments:argList];
        va_end(argList);
    }
    [[[UIAlertView alloc] initWithTitle:title message:result delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil] show];
}

//- (NSArray *)toolbarItems
//{
//    // Toolbar
//    NSMutableArray *items = [NSMutableArray arrayWithCapacity:9];
//    
//    addTaskListButton_ = [[UIBarButtonItem alloc] initWithTitle:@"+" style:UIBarButtonSystemItemAdd target:self action:@selector(addTaskListClicked:)];
//    renameTaskListButton_ = [[UIBarButtonItem alloc] initWithTitle:@"R" style:UIBarButtonSystemItemEdit target:self action:@selector(renameTaskListClicked:)];
//    deleteTaskListButton_ = [[UIBarButtonItem alloc] initWithTitle:@"X" style:UIBarButtonSystemItemAction target:self action:@selector(deleteTaskListClicked:)];
//    
//    UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
//                                                                                             target:nil
//                                                                                             action:nil];
//    
//    [items addObject:flexibleSpaceButtonItem];
//    [items addObject:addTaskListButton_];
//    [items addObject:flexibleSpaceButtonItem];
//    [items addObject:renameTaskListButton_];
//    [items addObject:flexibleSpaceButtonItem];
//    [items addObject:deleteTaskListButton_];
//    [items addObject:flexibleSpaceButtonItem];
//    
//    return items;
//}



#pragma mark - IBAction
- (void)addTaskListClicked:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"New Task"
                          message:@""
                          delegate:self
                          cancelButtonTitle: @"Cancel"
                          otherButtonTitles:@"OK", nil ];
    
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField* titleField = [alert textFieldAtIndex:0];
    titleField.keyboardType = UIKeyboardAppearanceDefault;
    titleField.placeholder = @"Type...";
    alert.tag = 110;
    [alert show];
}

- (void)renameTaskListClicked:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"Rename A Task"
                          message:@""
                          delegate:self
                          cancelButtonTitle: @"Cancel"
                          otherButtonTitles:@"OK", nil ];
    
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField* titleField = [alert textFieldAtIndex:0];
    titleField.keyboardType = UIKeyboardAppearanceDefault;
    titleField.placeholder = @"Type...";
    alert.tag = 111;
    [alert show];
}

- (void)deleteTaskListClicked:(id)sender {
    GTLTasksTaskList *tasklist = [self selectedTaskList];
    NSString *title = tasklist.title;
    [self displayAlert:@"Delete" format:@"Delete \"%@\"?", title];

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        [alertView dismissWithClickedButtonIndex:alertView.cancelButtonIndex animated:YES];
    } else {
        if (alertView.tag == 110 || alertView.tag == 111) {
            UITextField *taskString = [alertView textFieldAtIndex:0];
            if (alertView.tag  == 110) {
                [self addATaskList:taskString.text];
            } else if(alertView.tag == 111) {
                [self renameSelectedTaskList:taskString.text];
            }
        } else
            // from other alertView
            // might do other things
        {
            [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
            
        }
        
    }
}


#pragma mark - TasksList

- (void)fetchTaskLists {
    self.taskLists = nil;
    self.taskListsFetchError = nil;
    
    GTLServiceTasks *service = self.tasksService;

    GTLQueryTasks *query = [GTLQueryTasks queryForTasklistsList];
    
    [SVProgressHUD showWithStatus:NSLocalizedString(@"LOADING", @"Loading")];
    
    self.taskListsTicket = [service executeQuery:query
                               completionHandler:^(GTLServiceTicket *ticket,
                                                   id taskLists, NSError *error) {
                                   // callback
                                   [SVProgressHUD dismiss];
                                   
                                   self.taskLists = taskLists;
                                   self.taskListsFetchError = error;
                                   self.taskListsTicket = nil;
                                   
                                   [self updateUI];
                               }];
    [self updateUI];
}

- (void)updateUI
{
    // todo: needs to handle errors!
    if (self.taskListsTicket != nil || self.editTaskListTicket != nil) {
        [SVProgressHUD showWithStatus:@"Loading..."];
    } else {
        [SVProgressHUD dismiss];
    }
    
    // Get the description of the selected item, or the feed fetch error
    NSString *resultStr = @"";
    
    if (self.taskListsFetchError) {
        // Display the error
        resultStr = [self.taskListsFetchError description];
        
        // Also display any server data present
        NSData *errData = [[self.taskListsFetchError userInfo] objectForKey:kGTMHTTPFetcherStatusDataKey];
        if (errData) {
            NSString *dataStr = [[NSString alloc] initWithData:errData
                                                      encoding:NSUTF8StringEncoding];
            resultStr = [resultStr stringByAppendingFormat:@"\n%@", dataStr];
        }
        [SVProgressHUD showErrorWithStatus:resultStr];
    } else {
        // Display the selected item
        GTLTasksTaskList *item = [self selectedTaskList];
        if (item) {
            // this is all we care
            resultStr = [item description];
        }
    }
    //    [taskListsResultTextView_ setString:resultStr];
    
    
    BOOL hasTaskLists = (self.taskLists != nil);
    BOOL isTaskListSelected = ([self selectedTaskList] != nil);
    GTLTasksTaskList *item = [self selectedTaskList];
    
    BOOL hasTaskListTitle = ([item.title length] > 0);
    
    [addTaskListButton_ setEnabled:(hasTaskListTitle && hasTaskLists)];
    [renameTaskListButton_ setEnabled:(hasTaskListTitle && isTaskListSelected)];
    [deleteTaskListButton_ setEnabled:(isTaskListSelected)];

    // todo: we also allow the user canceling the fetching!
//    BOOL isFetchingTaskLists = (self.taskListsTicket != nil);
//    BOOL isEditingTaskList = (self.editTaskListTicket != nil);
//    [taskListsCancelButton_ setEnabled:(isFetchingTaskLists || isEditingTaskList)];
    
    [self.tableView reloadData];
    
}

#pragma mark - UI
-(void)onSignOut:(id)sender
{
    AppDelegate *delegate = [AppDelegate appDelegate];
    [delegate signOut];
    
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self){
    }
    
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"TASK_LIST", @"");
//    self.navigationController.navigationBar.alpha = 1.0;
    
    [self.slidingViewController setAnchorRightRevealAmount:280.0f];
    self.slidingViewController.underLeftWidthLayout = ECFullWidth;
    
    [SSThemeManager customizeTableView:self.tableView];
    
    
    NSString *clientID = myClientId;
    NSString *clientSecret = mySecretKey;
    
    GTMOAuth2Authentication *auth = nil;
    
    if (clientID && clientSecret) {
        auth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                     clientID:clientID
                                                                 clientSecret:clientSecret];
    }
    self.tasksService.authorizer = auth;
    
    
//    [self.navigationController setToolbarHidden:NO];
//    [self setToolbarItems:[self toolbarItems]];

    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
    
//    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
//    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTaskListClicked:)];
//    self.navigationItem.rightBarButtonItem = addItem;
//    
//    UIBarButtonItem *signOutItem = [[UIBarButtonItem alloc] initWithTitle:@"SignOut" style:UIBarButtonItemStyleBordered target:self action:@selector(onSignOut:)];
//    self.navigationItem.leftBarButtonItem = signOutItem;

    // Long press recognizer
    UILongPressGestureRecognizer *longpressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    [self.tableView addGestureRecognizer:longpressRecognizer];
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self fetchTaskLists];
    });
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.taskLists.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    // Configure the cell...
    GTLTasksTaskList *item = self.taskLists[indexPath.row];
    cell.textLabel.text = item.title;
    cell.textLabel.font = SYSTEM_TEXT_FONT;
    cell.textLabel.textColor = SYSTEM_TEXT_COLOR;
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    [tableView deselectRowAtIndexPath:indexPath animated:NO];
//    [self updateUI];
    GTLTasksTaskList *selectedTasklist = [self selectedTaskList];
    
    // Navigation logic may go here. Create and push another view controller.
    TaskTasksViewController *detailViewController = [[TaskTasksViewController alloc] initWithStyle:UITableViewStylePlain];
    
    // todo: super stupid
    detailViewController.selectedTasklist = selectedTasklist;
    detailViewController.tasksService = self.tasksService;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
    // ...
    // Pass the selected object to the new view controller.
    [self.slidingViewController anchorTopViewOffScreenTo:ECRight animations:nil onComplete:^{
        CGRect frame = self.slidingViewController.topViewController.view.frame;
        self.slidingViewController.topViewController = navController;
        self.slidingViewController.topViewController.view.frame = frame;
        [self.slidingViewController resetTopView];
    }];
    
//    [self.navigationController pushViewController:detailViewController animated:YES];
}


#pragma mark - setter & getter

- (GTLTasksTaskList *)selectedTaskList {
  
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    
    // to make it simple
    if (indexPath == nil)
        indexPath = self.selectedIndexPath;
    
    if (indexPath.row > -1) {
        GTLTasksTaskList *item = [self.taskLists itemAtIndex:indexPath.row];
        return item;
    }
    return nil;
}

//- (GTLTasksTaskList *)selectedTaskListForIndexPath:(NSIndexPath *)indexPath {
//    
////    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
//    if (indexPath.row > -1) {
//        GTLTasksTaskList *item = [self.taskLists itemAtIndex:indexPath.row];
//        return item;
//    }
//    return nil;
//}


#pragma mark Add a Task List

- (void)addATaskList:(NSString *)title {
    if ([title length] > 0) {
        // Make a new task list
        GTLTasksTaskList *tasklist = [GTLTasksTaskList object];
        tasklist.title = title;
        
        GTLQueryTasks *query = [GTLQueryTasks queryForTasklistsInsertWithObject:tasklist];
        
        GTLServiceTasks *service = self.tasksService;
        self.editTaskListTicket = [service executeQuery:query
                                      completionHandler:^(GTLServiceTicket *ticket,
                                                          id item, NSError *error) {
                                          // callback
                                          self.editTaskListTicket = nil;
                                          GTLTasksTaskList *tasklist = item;
                                          
                                          if (error == nil) {
                                              [self displayAlertWithMessage:[NSString stringWithFormat:@"Added task list \"%@\"", tasklist.title]];
                                              [self fetchTaskLists];
                                          } else {
                                              [self displayAlertWithMessage:[NSString stringWithFormat:@"error: \"%@\"", error]];
                                              [self updateUI];
                                          }
                                      }];
        [self updateUI];
    }
}

#pragma mark Rename a Task List

- (void)renameSelectedTaskList:(NSString *)title{
    
    if ([title length] > 0) {
        // Rename the selected task list
        
        // Rather than update the object with a complete replacement, we'll make
        // a patch object containing just the changed title
        GTLTasksTaskList *patchObject = [GTLTasksTaskList object];
        patchObject.title = title;
        
        GTLTasksTaskList *selectedTaskList = [self selectedTaskList];
        
        GTLQueryTasks *query = [GTLQueryTasks queryForTasklistsPatchWithObject:patchObject
                                                                      tasklist:selectedTaskList.identifier];
        GTLServiceTasks *service = self.tasksService;
        self.editTaskListTicket = [service executeQuery:query
                                      completionHandler:^(GTLServiceTicket *ticket,
                                                          id item, NSError *error) {
                                          // callback
                                          self.editTaskListTicket = nil;
                                          GTLTasksTaskList *tasklist = item;
                                          
                                          if (error == nil) {
                                              [self displayAlertWithMessage:[NSString stringWithFormat:@"Updated task list \"%@\"", tasklist.title]];
                                              //                                              [self displayAlert:@"Task List Updated"
                                              //                                                          format:@"Updated task list \"%@\"", tasklist.title];
                                              [self fetchTaskLists];
                                              //                                              [taskListNameField_ setStringValue:@""];
                                          } else {
                                              [self displayAlertWithMessage:[NSString stringWithFormat:@"error: \"%@\"", error]];
                                              //                                              [self displayAlert:@"Error"
                                              //                                                          format:@"%@", error];
                                              [self updateUI];
                                          }
                                      }];
        [self updateUI];
    }
}

#pragma mark Delete a Task List

- (void)deleteSelectedTaskList {
    GTLTasksTaskList *tasklist = [self selectedTaskList];
    
    GTLQueryTasks *query = [GTLQueryTasks queryForTasklistsDeleteWithTasklist:tasklist.identifier];
    
    GTLServiceTasks *service = self.tasksService;
    self.editTaskListTicket = [service executeQuery:query
                                  completionHandler:^(GTLServiceTicket *ticket,
                                                      id item, NSError *error) {
                                      // callback
                                      self.editTaskListTicket = nil;
                                      
                                      if (error == nil) {
                                          [self displayAlertWithMessage:[NSString stringWithFormat:@"Delete task list \"%@\"", tasklist.title]];
                                          [self fetchTaskLists];
                                      } else {
                                          [self displayAlertWithMessage:[NSString stringWithFormat:@"error: \"%@\"", error]];
                                          [self updateUI];
                                      }
                                  }];
    [self updateUI];
}

#pragma mark - Gesture
- (void)onLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan)
    {
        UITableViewCell *cell = (UITableViewCell *)[gesture view];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        self.selectedIndexPath = indexPath;
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"ACTION", @"action") delegate:self cancelButtonTitle:NSLocalizedString(@"CANCEL", @"cancel") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"EDIT_TITLE",@"edit title"), NSLocalizedString(@"DELETE", @"delete"), nil];
        [actionSheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES];
        
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [actionSheet dismissWithClickedButtonIndex:actionSheet.cancelButtonIndex animated:YES];
    } else if (buttonIndex == 0){ //edit
        [self renameTaskListClicked:nil];
    } else if (buttonIndex == 1) { //delete
        [self deleteTaskListClicked:nil];
    }
    
}

- (GTLServiceTasks *)tasksService {
    static GTLServiceTasks *service = nil;
    
    if (!service) {
        service = [[GTLServiceTasks alloc] init];
        
        // Have the service object set tickets to fetch consecutive pages
        // of the feed so we do not need to manually fetch them
        service.shouldFetchNextPages = YES;
        
        // Have the service object set tickets to retry temporary error conditions
        // automatically
        service.retryEnabled = YES;
    }
    return service;
}
//

@end
