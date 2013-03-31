
#import "RootViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTMOAuth2SignIn.h"
#import "GTLUtilities.h"
#import "GTMHTTPFetcherLogging.h"
#import "TaskListViewController.h"

static NSString *const kShouldSaveInKeychainKey = @"shouldSaveInKeychain";
static NSString *const kSampleClientIDKey = @"clientID";
static NSString *const kSampleClientSecretKey = @"clientSecret";

@interface RootViewController()
{
    UIBarButtonItem *signInOutButton_;
    UIBarButtonItem *fetchButton_;
    UIBarButtonItem *expireNowButton_;
}

@property (readonly) GTLServiceTasks *tasksService;
@property (nonatomic, strong) UIBarButtonItem *signInOutButton;
@property (nonatomic, strong) UIBarButtonItem *fetchButton;
@property (nonatomic, strong) UIBarButtonItem *expireNowButton;


- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error;
- (void)incrementNetworkActivity:(NSNotification *)notify;
- (void)decrementNetworkActivity:(NSNotification *)notify;
- (void)signInNetworkLostOrFound:(NSNotification *)notify;
- (void)doAnAuthenticatedAPIFetch;
- (BOOL)shouldSaveInKeychain;

@end

// Keychain item name for saving the user's authentication information
NSString *const kKeychainItemName = @"gTasks: Google Tasks";

@implementation RootViewController

@synthesize emailField = mEmailField,
            fetchButton = fetchButton_,
            expireNowButton = expireNowButton_,
            shouldSaveInKeychainSwitch = mShouldSaveInKeychainSwitch,
            signInOutButton = signInOutButton_;

@synthesize auth = mAuth;

// NSUserDefaults keys
static NSString *const kGoogleClientIDKey          = @"GoogleClientID";
static NSString *const kGoogleClientSecretKey      = @"GoogleClientSecret";
static NSString *const kDailyMotionClientIDKey     = @"DailyMotionClientID";
static NSString *const kDailyMotionClientSecretKey = @"DailyMotionClientSecret";

- (void)awakeFromNib {
  // Listen for network change notifications
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(incrementNetworkActivity:) name:kGTMOAuth2WebViewStartedLoading object:nil];
  [nc addObserver:self selector:@selector(decrementNetworkActivity:) name:kGTMOAuth2WebViewStoppedLoading object:nil];
  [nc addObserver:self selector:@selector(incrementNetworkActivity:) name:kGTMOAuth2FetchStarted object:nil];
  [nc addObserver:self selector:@selector(decrementNetworkActivity:) name:kGTMOAuth2FetchStopped object:nil];
  [nc addObserver:self selector:@selector(signInNetworkLostOrFound:) name:kGTMOAuth2NetworkLost  object:nil];
  [nc addObserver:self selector:@selector(signInNetworkLostOrFound:) name:kGTMOAuth2NetworkFound object:nil];

  // Fill in the Client ID and Client Secret text fields
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  // First, we'll try to get the saved Google authentication, if any, from
  // the keychain

  // Normal applications will hardcode in their client ID and client secret,
  // but the sample app allows the user to enter them in a text field, and
  // saves them in the preferences
  NSString *clientID = [defaults stringForKey:kGoogleClientIDKey];
  NSString *clientSecret = [defaults stringForKey:kGoogleClientSecretKey];

  GTMOAuth2Authentication *auth = nil;

  if (clientID && clientSecret) {
    auth = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                      clientID:clientID
                                                                  clientSecret:clientSecret];
  }
  // Save the authentication object, which holds the auth tokens and
  // the scope string used to obtain the token.  For Google services,
  // the auth object also holds the user's email address.
  self.auth = auth;

    
  // Update the client ID value text fields to match the radio button selection

  BOOL isRemembering = [self shouldSaveInKeychain];
  self.shouldSaveInKeychainSwitch.on = isRemembering;
    
    [self.navigationController setToolbarHidden:NO];
    
    [self setToolbarItems:[self toolbarItems]];

  [self updateUI];
}


- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];


}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  // Returns non-zero on iPad, but backward compatible to SDKs earlier than 3.2.
  if (UI_USER_INTERFACE_IDIOM()) {
    return YES;
  }
  return [super shouldAutorotateToInterfaceOrientation:orientation];
}

// I think this one matters.
- (BOOL)isSignedIn {
  BOOL isSignedIn = self.auth.canAuthorize;
  return isSignedIn;
}


- (void)signInOutClicked:(id)sender {

  if (![self isSignedIn]) {
      [self signInToGoogle];
  } else {
    // Sign out
    [self signOut];
  }
  [self updateUI];
}

- (void)fetchClicked:(id)sender {
  // Just to prove we're signed in, we'll attempt an authenticated fetch for the
  // signed-in user
  [self doAnAuthenticatedAPIFetch];
}

- (void)expireNowClicked:(id)sender {
  NSDate *date = self.auth.expirationDate;
  if (date) {
    self.auth.expirationDate = [NSDate dateWithTimeIntervalSince1970:0];
    [self updateUI];
  }
}

// UISwitch does the toggling for us. We just need to read the state.
- (IBAction)toggleShouldSaveInKeychain:(UISwitch *)sender {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:sender.isOn forKey:kShouldSaveInKeychainKey];
}

- (void)signOut {
  if ([self.auth.serviceProvider isEqual:kGTMOAuth2ServiceProviderGoogle]) {
    // remove the token from Google's servers
    [GTMOAuth2ViewControllerTouch revokeTokenForGoogleAuthentication:self.auth];
  }

  // remove the stored Google authentication from the keychain, if any
  [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];

  // remove the stored DailyMotion authentication from the keychain, if any

  // Discard our retained authentication object.
  self.auth = nil;

  [self updateUI];
}

#define myClientId @"580813237419.apps.googleusercontent.com"
#define mySecretKey @"1XLt_eUMs7hdIiqSDt04qe4-"

- (void)signInToGoogle {
  [self signOut];

  NSString *keychainItemName = nil;
  if ([self shouldSaveInKeychain]) {
    keychainItemName = kKeychainItemName;
  }

  // For Google APIs, the scope strings are available
  // in the service constant header files.
  NSString *scope = @"https://www.googleapis.com/auth/tasks";

  // Typically, applications will hardcode the client ID and client secret
  // strings into the source code; they should not be user-editable or visible.
  //
  // But for this sample code, they are editable.
    NSString *clientID = myClientId; // self.clientIDField.text;
    NSString *clientSecret = mySecretKey; //self.clientSecretField.text;

  // Note:
  // GTMOAuth2ViewControllerTouch is not designed to be reused. Make a new
  // one each time you are going to show it.

  // Display the autentication view.
  SEL finishedSel = @selector(viewController:finishedWithAuth:error:);

  GTMOAuth2ViewControllerTouch *viewController;
  viewController = [GTMOAuth2ViewControllerTouch controllerWithScope:scope
                                                            clientID:clientID
                                                        clientSecret:clientSecret
                                                    keychainItemName:keychainItemName
                                                            delegate:self
                                                    finishedSelector:finishedSel];

  // You can set the title of the navigationItem of the controller here, if you
  // want.

  // If the keychainItemName is not nil, the user's authorization information
  // will be saved to the keychain. By default, it saves with accessibility
  // kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, but that may be
  // customized here. For example,
  //
  //   viewController.keychainItemAccessibility = kSecAttrAccessibleAlways;

  // During display of the sign-in window, loss and regain of network
  // connectivity will be reported with the notifications
  // kGTMOAuth2NetworkLost/kGTMOAuth2NetworkFound
  //
  // See the method signInNetworkLostOrFound: for an example of handling
  // the notification.

  // Optional: Google servers allow specification of the sign-in display
  // language as an additional "hl" parameter to the authorization URL,
  // using BCP 47 language codes.
  //
  // For this sample, we'll force English as the display language.
  NSDictionary *params = @{@"hl": @"en"};
  viewController.signIn.additionalAuthorizationParameters = params;

  // By default, the controller will fetch the user's email, but not the rest of
  // the user's profile.  The full profile can be requested from Google's server
  // by setting this property before sign-in:
  //
  //   viewController.signIn.shouldFetchGoogleUserProfile = YES;
  //
  // The profile will be available after sign-in as
  //
  //   NSDictionary *profile = viewController.signIn.userProfile;

  // Optional: display some html briefly before the sign-in page loads
  NSString *html = @"<html><body bgcolor=silver><div align=center>Loading sign-in page...</div></body></html>";
  viewController.initialHTMLString = html;

  [[self navigationController] pushViewController:viewController animated:YES];

  // The view controller will be popped before signing in has completed, as
  // there are some additional fetches done by the sign-in controller.
  // The kGTMOAuth2UserSignedIn notification will be posted to indicate
  // that the view has been popped and those additional fetches have begun.
  // It may be useful to display a temporary UI when kGTMOAuth2UserSignedIn is
  // posted, just until the finished selector is invoked.
}

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
  if (error != nil) {
    // Authentication failed (perhaps the user denied access, or closed the
    // window before granting access)
    DebugLog(@"Authentication error: %@", error);
    NSData *responseData = [error userInfo][@"data"]; // kGTMHTTPFetcherStatusDataKey
    if ([responseData length] > 0) {
      // show the body of the server's authentication failure response
      NSString *str = [[NSString alloc] initWithData:responseData
                                             encoding:NSUTF8StringEncoding];
      DebugLog(@"%@", str);
    }

    self.auth = nil;
  } else {
    // Authentication succeeded
    //
    //
      DebugLog(@"auth: succesfully!");
//      if (error == nil) {
//          self.tasksService.authorizer = auth;
//          TaskListViewController *tasksListViewController = [[TaskListViewController alloc] initWithStyle:UITableViewStylePlain];
//          tasksListViewController.tasksService = self.tasksService;
//          
//          [self.navigationController pushViewController:tasksListViewController animated:YES];
//          
//          DebugLog(@"sign in succesfuuly");
//      } else {
//          self.taskListsFetchError = error;
//          [self updateUI];
//      }

    // save the authentication object
    self.auth = auth;
  }

  [self updateUI];
}

- (void)doAnAuthenticatedAPIFetch {
    NSString *urlStr = @"https://www.googleapis.com/tasks/v1/users/@me/lists";

  NSURL *url = [NSURL URLWithString:urlStr];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [self.auth authorizeRequest:request
            completionHandler:^(NSError *error) {
              NSString *output = nil;
              if (error) {
                output = [error description];
              } else {
               
                  self.tasksService.authorizer = self.auth;
                  TaskListViewController *tasksListViewController = [[TaskListViewController alloc] initWithStyle:UITableViewStylePlain];
                  tasksListViewController.tasksService = self.tasksService;
                  
                  [self.navigationController pushViewController:tasksListViewController animated:YES];
                  
              }

            }];
    
}

#pragma mark -

- (void)incrementNetworkActivity:(NSNotification *)notify {
  ++mNetworkActivityCounter;
  if (mNetworkActivityCounter == 1) {
    UIApplication *app = [UIApplication sharedApplication];
    [app setNetworkActivityIndicatorVisible:YES];
  }
}

- (void)decrementNetworkActivity:(NSNotification *)notify {
  --mNetworkActivityCounter;
  if (mNetworkActivityCounter == 0) {
    UIApplication *app = [UIApplication sharedApplication];
    [app setNetworkActivityIndicatorVisible:NO];
  }
}

- (void)signInNetworkLostOrFound:(NSNotification *)notify {
  if ([[notify name] isEqual:kGTMOAuth2NetworkLost]) {
    // network connection was lost; alert the user, or dismiss
    // the sign-in view with
    [[[notify object] delegate] cancelSigningIn];
  } else {
    // network connection was found again
  }
}

#pragma mark -

- (void)updateUI {
  // update the text showing the signed-in state and the button title
  // A real program would use NSLocalizedString() for strings shown to the user.
  if ([self isSignedIn]) {
    // signed in
    self.emailField.text = self.auth.userEmail;
//    self.accessTokenField.text = self.auth.accessToken;
//    self.expirationField.text = [self.auth.expirationDate description];
//    self.refreshTokenField.text = self.auth.refreshToken;

    self.signInOutButton.title = @"Sign Out";
    self.fetchButton.enabled = YES;
    self.expireNowButton.enabled = YES;
  } else {
    // signed out
    self.emailField.text = @"";
//    self.accessTokenField.text = @"-No access token-";
//    self.expirationField.text = @"";
//    self.refreshTokenField.text = @"-No refresh token-";

    self.signInOutButton.title = @"Sign In";
    self.fetchButton.enabled = NO;
    self.expireNowButton.enabled = NO;
  }

  BOOL isRemembering = [self shouldSaveInKeychain];
  self.shouldSaveInKeychainSwitch.on = isRemembering;
    
}


- (BOOL)shouldSaveInKeychain {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL flag = [defaults boolForKey:kShouldSaveInKeychainKey];
  return flag;
}

#pragma mark -
// get a service object with the current username/password
//
// A "service" object handles networking tasks.  Service objects
// contain user authentication information as well as networking
// state information (such as cookies and the "last modified" date for
// fetched data.)

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

#pragma mark - toolbar items
- (NSArray *)toolbarItems
{
    // Toolbar
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:9];
    
    signInOutButton_ = [[UIBarButtonItem alloc] initWithTitle:@"Sign In" style:UIBarButtonItemStyleBordered target:self action:@selector(signInOutClicked:)];
    fetchButton_ = [[UIBarButtonItem alloc] initWithTitle:@"Fetch" style:UIBarButtonItemStyleBordered target:self action:@selector(fetchClicked:)];
    expireNowButton_ = [[UIBarButtonItem alloc] initWithTitle:@"Expire Now" style:UIBarButtonItemStyleBordered target:self action:@selector(expireNowClicked:)];
    
    UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                             target:nil
                                                                                             action:nil];
    
    
    [items addObject:flexibleSpaceButtonItem];
    [items addObject:signInOutButton_];
    [items addObject:flexibleSpaceButtonItem];
    [items addObject:fetchButton_];
    [items addObject:flexibleSpaceButtonItem];
    [items addObject:expireNowButton_];
    [items addObject:flexibleSpaceButtonItem];
    
    return items;
}


@end
