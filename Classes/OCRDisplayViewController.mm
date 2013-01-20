//
//  OCRDisplayViewController.m
//  OCR
//
//  Created by Robert Carlsen on 03.12.2009.
//
//    Copyright (C) 2009, Robert Carlsen | robertcarlsen.net
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "OCRDisplayViewController.h"
#import "baseapi.h"
#import "UIImage+Resize.h"
#import "EvernoteViewController.h"
#import "DropBoxViewController.h"
#import <math.h>

typedef enum {
    kImport,
    kExport
} buttonType;
#define kViewTitle @"Pocket Tesseract OCR"

@implementation OCRDisplayViewController

@synthesize outputString,outputView,cameraButton, actionButton, thumbImageView, statusLabel;

- (void)dealloc 
{
    tess->End(); // shutdown tesseract
    [imageForOCR release];
    [outputView release];
    [thumbImageView release];
    [statusLabel release];
    
    [super dealloc];
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
    
    [statusLabel setText:kViewTitle];

    activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityView.center = self.view.center;
    activityView.hidesWhenStopped = YES;
    [self.view addSubview:activityView];
    
    // Set up the tessdata path. This is included in the application bundle
    // but is copied to the Documents directory on the first run.
    NSString *dataPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"tessdata"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // If the expected store doesn't exist, copy the default store.
    if (![fileManager fileExistsAtPath:dataPath]) {
        // get the path to the app bundle (with the tessdata dir)
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *tessdataPath = [bundlePath stringByAppendingPathComponent:@"tessdata"];
        if (tessdataPath) {
            [fileManager copyItemAtPath:tessdataPath toPath:dataPath error:NULL];
        }
    }
    
    NSString *dataPathWithSlash = [[self applicationDocumentsDirectory] stringByAppendingString:@"/"];
    setenv("TESSDATA_PREFIX", [dataPathWithSlash UTF8String], 1);
    
    // init the tesseract engine.
    tess = new TessBaseAPI();
    tess->Init([dataPathWithSlash cStringUsingEncoding:NSUTF8StringEncoding], "eng");
    
    //tesseract::PageSegMode pagesegmode = tesseract::PSM_AUTO;
    tess->SetPageSegMode(tesseract::PSM_AUTO);

    [outputView setText:@"Select an image to process."];

}

// This displays the converted text in the view
-(void)updateTextDisplay;
{
    [activityView stopAnimating];
    
    [statusLabel setText:kViewTitle];
    [outputView setText:outputString]; 
    
    [thumbImageView shrinkToThumbnail];
}

// non-threaded...don't use.
- (NSString *)readAndProcessImage:(UIImage *)uiImage 
{
    CGSize imageSize = [uiImage size];
    int bytes_per_line  = (int)CGImageGetBytesPerRow([uiImage CGImage]);
    int bytes_per_pixel = (int)CGImageGetBitsPerPixel([uiImage CGImage]) / 8.0;
    
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider([uiImage CGImage]));
    const UInt8 *imageData = CFDataGetBytePtr(data);
    
    // this could take a while. maybe needs to happen asynchronously?
    char* text = tess->TesseractRect(imageData, bytes_per_pixel, bytes_per_line,
                                     0, 0, imageSize.width, imageSize.height);
   
    NSString *textStr = [NSString stringWithUTF8String:text];
    delete[] text;
    CFRelease(data);
    return textStr;
}

// preferred, threaded method:
- (void)threadedReadAndProcessImage:(UIImage *)uiImage 
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    CGSize imageSize = [uiImage size];
    int bytes_per_line  = (int)CGImageGetBytesPerRow([uiImage CGImage]);
    int bytes_per_pixel = (int)CGImageGetBitsPerPixel([uiImage CGImage]) / 8.0;
    
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider([uiImage CGImage]));
    const UInt8 *imageData = CFDataGetBytePtr(data);
    
    // this could take a while.
    char* text = tess->TesseractRect(imageData,
                                     bytes_per_pixel,
                                     bytes_per_line,
                                     0, 0,
                                     imageSize.width, imageSize.height);
    
    [self setOutputString:[NSString stringWithCString:text encoding:NSUTF8StringEncoding]];
    
    delete[] text;
    CFRelease(data);

    // Update the display text. Since we're in a threaded method, run the UI stuff on the main thread.
    [self performSelectorOnMainThread:@selector(updateTextDisplay) withObject:nil waitUntilDone:NO];
    
    [pool release];
}

- (UIImage*)imageWithImage:(UIImage*)image 
              scaledToSize:(CGSize)newSize;
{
    // calculate aspect ratio:
    float ratio = image.size.height / image.size.width;
    float aspectHeight = newSize.width * ratio;
    CGSize ratioSize = CGSizeMake(newSize.width, aspectHeight);
    
    UIGraphicsBeginImageContext( ratioSize );
    [image drawInRect:CGRectMake(0,0,ratioSize.width,ratioSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

#pragma mark -
#pragma mark Application's documents directory
/**
 Returns the path to the application's documents directory.
 */
- (NSString *)applicationDocumentsDirectory 
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}


#pragma mark Image Selection methods
- (IBAction) selectImage: (id) sender
{    
    // present an alert sheet if a camera is visible and allow the user to select the camera or photo library.
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        // this device has a camera, display the alert sheet:
        UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                      initWithTitle:@"Select Image Source"
                                      delegate:self 
                                      cancelButtonTitle:@"Cancel" 
                                      destructiveButtonTitle:nil
                                      otherButtonTitles:@"Camera",@"Photo Library", nil];
        [actionSheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
        [actionSheet setTag:kImport];
        // the tab bar was interferring in the current view
        [actionSheet showInView:[[UIApplication sharedApplication] keyWindow]]; 
        [actionSheet release];
    } else {
        // without a camera, there is no choice to make. just display the modal image picker
        [self displayImagePickerWithSource:UIImagePickerControllerSourceTypePhotoLibrary];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex;
{
    switch (actionSheet.tag) {
        case kImport:
            switch (buttonIndex) {
                case 0:
                    // Camera Button
                    [self displayImagePickerWithSource:UIImagePickerControllerSourceTypeCamera];
                    break;
                case 1:
                    // Library Button
                    [self displayImagePickerWithSource:UIImagePickerControllerSourceTypePhotoLibrary];
                    break;
                case 2:
                    // Cancel Button
                    break;
                default:
                    break;
            }
            break;
        case kExport:
            switch (buttonIndex) {
                case 0: {
                    EvernoteViewController *everNote = [self.storyboard instantiateViewControllerWithIdentifier:@"Evernote"];
                    [everNote setModalPresentationStyle:UIModalPresentationFullScreen];
                    [self presentViewController:everNote animated:YES completion:nil];
                    }
                    break;
                case 1: {
                    DropBoxViewController *dropBox = [self.storyboard instantiateViewControllerWithIdentifier:@"DropBox"];
                    [dropBox setModalPresentationStyle:UIModalPresentationFullScreen];
                    [self presentViewController:dropBox animated:YES completion:nil];
                    }
                    break;
                case 2: {
                    [self displayComposerSheet];
                }
                default:
                    break;
            }
        default:
            break;
    }
    
}

- (void)displayImagePickerWithSource:(UIImagePickerControllerSourceType)src;
{
    if([UIImagePickerController isSourceTypeAvailable:src]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        [picker setSourceType:src];
        [picker setDelegate:self];
        
        // allowing editing is nice, but only returns a small 320px image
        [picker setAllowsEditing:YES]; 
        [self presentViewController:picker animated:YES completion:nil];
        [picker release];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSLog(@"Picker has returned");
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // process the selected image:
    [activityView startAnimating];
    
    [statusLabel setText:@"Processing image..."];
    [outputView setText:@""];
        
    // send the edited image to the thumbnail view:
    UIImage *thumbImage = [[info objectForKey:UIImagePickerControllerEditedImage] retain];
    
    // set the thumbnail image:    
    [thumbImageView setImage:thumbImage];
    [thumbImage release];
    
    // zoom the thumbnail
    [thumbImageView zoomImageToCenter];

    // TODO: make this all threaded?
    // crop the image to the bounds provided
    UIImage *origImage = [[info objectForKey:UIImagePickerControllerOriginalImage] retain];    
    NSLog(@"orig image size: %@", [[NSValue valueWithCGSize:origImage.size] description]);
    
    // save the image, only if it's a newly taken image:
    if([picker sourceType] == UIImagePickerControllerSourceTypeCamera){
        UIImageWriteToSavedPhotosAlbum(origImage, nil, nil, nil); 
    }
    
    CGRect rect;
    [[info objectForKey:UIImagePickerControllerCropRect] getValue:&rect];
    
    // fake resize to get the orientation right
    UIImage *croppedImage= [origImage resizedImage:origImage.size interpolationQuality:kCGInterpolationDefault];
    [origImage release];
    
    // crop, but maintain original size:
    croppedImage = [croppedImage croppedImage:rect];
    NSLog(@"cropped image size: %@", [[NSValue valueWithCGSize:croppedImage.size] description]);

    // process image, threaded:
    [self performSelector:@selector(threadedReadAndProcessImage:) withObject:croppedImage afterDelay:0.10];
}



#pragma mark MailComposer delegate
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error;
{
    NSString *message;
    message = nil;
    
    // Notifies users about errors associated with the interface
	switch (result)
	{
		case MFMailComposeResultCancelled:
			break;
		case MFMailComposeResultSaved:
			break;
		case MFMailComposeResultSent:
			break;
		case MFMailComposeResultFailed:
            message = @"Mail Failed.";
			break;
		default:
			break;
	}
	[self dismissViewControllerAnimated:YES completion:nil];
    
    if(message != nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Status"
                                                        message:message delegate:nil 
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

- (IBAction)saveText:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@"Save Text"
                                  delegate:self
                                  cancelButtonTitle:@"Cancel"
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:@"Evernote", @"DropBox", @"Email", nil];
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackOpaque];
    [actionSheet setTag:kExport];
    // the tab bar was interferring in the current view
    [actionSheet showInView:[[UIApplication sharedApplication] keyWindow]];
    [actionSheet release];
}

// Displays an email composition interface inside the application. Populates all the Mail fields.
- (void)displayComposerSheet
{
    if(![MFMailComposeViewController canSendMail]) {
        // can't send mail.
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Mail not configured or available." 
                                                       delegate:nil 
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    
	MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    [[picker navigationBar] setTintColor:[UIColor blackColor]];

    [picker setMailComposeDelegate:self];
	
	[picker setSubject:@"iPhoneOCR Text"]; // use the product name?

	// Fill out the email body text
    [picker setMessageBody:outputString isHTML:NO];

	[self presentViewController:picker animated:YES completion:nil];
    [picker release];
    
}


//#pragma mark Touch events
//- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
//    NSLog(@"-- I AM TOUCH-ENDED --");
//    
//}

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
    // TODO: clean this up.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}



@end
