//
//  EvernoteViewController.h
//  OCR
//
//  Created by Mark Rommelfanger on 12/1/12.
//
//

#import <UIKit/UIKit.h>

@interface EvernoteViewController : UIViewController

- (IBAction)dismiss:(id)sender;
- (IBAction)authenticate:(id)sender;
- (IBAction)listNotes:(id)sender;
- (IBAction)logout:(id)sender;
@property (retain, nonatomic) IBOutlet UIButton *dismissButton;
@property (retain, nonatomic) IBOutlet UILabel *userLabel;
@property (retain, nonatomic) IBOutlet UIButton *listNotebooksButton;
@property (retain, nonatomic) IBOutlet UIButton *authenticateButton;
@property (retain, nonatomic) IBOutlet UIButton *logoutButton;


@end
