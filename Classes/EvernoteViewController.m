//
//  EvernoteViewController.m
//  OCR
//
//  Created by Mark Rommelfanger on 12/1/12.
//
//

#import "EvernoteViewController.h"
#import "EvernoteSDK.h"

@interface EvernoteViewController ()

@end

@implementation EvernoteViewController

@synthesize dismissButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (IBAction)dismiss:(id)sender;
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    // Initial development is done on the sandbox service
    // Change this to @"www.evernote.com" to use the production Evernote service
    // Change this to @"app.yinxiang.com" to use the Yinxiang Biji production service
    // sandbox.evernote.com does not support the  Yinxiang Biji service
    NSString *EVERNOTE_HOST = @"sandbox.evernote.com";
    
    // Fill in the consumer key and secret with the values that you received from Evernote
    // To get an API key, visit http://dev.evernote.com/documentation/cloud/
    NSString *CONSUMER_KEY = @"mrommelf";
    NSString *CONSUMER_SECRET = @"44d2b5b7d2dc61a7";
    
    // This setting controls if your app supports Evernote International and/or Yinxiang Biji
    EvernoteService service = EVERNOTE_SERVICE_INTERNATIONAL;
    
    // set up Evernote session singleton
    [EvernoteSession setSharedSessionHost:EVERNOTE_HOST
                              consumerKey:CONSUMER_KEY
                           consumerSecret:CONSUMER_SECRET
                         supportedService:service];
}

- (IBAction)authenticate:(id)sender
{
    EvernoteSession *session = [EvernoteSession sharedSession];
    [session authenticateWithViewController:self completionHandler:^(NSError *error) {
        if (error || !session.isAuthenticated) {
            UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error"
                                                             message:@"Could not authenticate"
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil] autorelease];
            [alert show];
        } else {
            NSLog(@"authenticated! noteStoreUrl:%@ webApiUrlPrefix:%@", session.noteStoreUrl, session.webApiUrlPrefix);
            [self updateButtonsForAuthentication];
        }
    }];
}

- (void)showUserInfo
{
    EvernoteUserStore *userStore = [EvernoteUserStore userStore];
    [userStore getUserWithSuccess:^(EDAMUser *user) {
        self.userLabel.text = user.username;
    }
                          failure:^(NSError *error) {
                              NSLog(@"error %@", error);
                          }];
}

- (IBAction)listNotes:(id)sender {
    EvernoteNoteStore *noteStore = [EvernoteNoteStore noteStore];
    [noteStore listNotebooksWithSuccess:^(NSArray *notebooks) {
        NSLog(@"notebooks: %@", notebooks);
    }
                                failure:^(NSError *error) {
                                    NSLog(@"error %@", error);
                                }];
}

- (void)updateButtonsForAuthentication
{
    EvernoteSession *session = [EvernoteSession sharedSession];
    
    if (session.isAuthenticated) {
        self.authenticateButton.enabled = NO;
        self.authenticateButton.alpha = 0.5;
        self.listNotebooksButton.enabled = YES;
        self.listNotebooksButton.alpha = 1.0;
        self.logoutButton.enabled = YES;
        self.logoutButton.alpha = 1.0;
        [self showUserInfo];
    } else {
        self.authenticateButton.enabled = YES;
        self.authenticateButton.alpha = 1.0;
        self.listNotebooksButton.enabled = NO;
        self.listNotebooksButton.alpha = 0.5;
        self.logoutButton.enabled = NO;
        self.logoutButton.alpha = 0.5;
        self.userLabel.text = @"(not authenticated)";
    }
}

- (IBAction)logout:(id)sender {
    [[EvernoteSession sharedSession] logout];
    [self updateButtonsForAuthentication];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
