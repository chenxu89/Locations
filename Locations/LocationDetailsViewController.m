//
//  LocationDetailsViewController.m
//  Locations
//
//  Created by 陈旭 on 5/21/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import "LocationDetailsViewController.h"
#import "CategoryPickerViewController.h"
#import "HudView.h"
#import "Location.h"
#import "NSMutableString+AddText.h"

@interface LocationDetailsViewController ()<UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>

@property (nonatomic, weak)IBOutlet UITextView *descriptionTextView;
@property (nonatomic, weak)IBOutlet UILabel *categoryLabel;
@property (nonatomic, weak)IBOutlet UILabel *latitudeLabel;
@property (nonatomic, weak)IBOutlet UILabel *longitudeLabel;
@property (nonatomic, weak)IBOutlet UILabel *addressLabel;
@property (nonatomic, weak)IBOutlet UILabel *dateLabel;
@property (nonatomic, weak)IBOutlet UIImageView *imageView;
@property (nonatomic, weak)IBOutlet UILabel *photoLabel;

@end

@implementation LocationDetailsViewController
{
    NSString *_descriptionText;
    NSString *_categoryName;
    NSDate *_date;
    UIImage *_image;
    // change the after two local variables to instance variables so that applicationDidEnterBackground can access these objects.
    UIActionSheet *_actionSheet;
    UIImagePickerController *_imagePicker;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        _descriptionText = @"";
        _categoryName = @"No Category";
        _date = [NSDate date];
    }
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(applicationDidEnterBackground)
     name:UIApplicationDidEnterBackgroundNotification
     object:nil];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)done:(id)sender
{
    HudView *hudView = [HudView hudInView:self.navigationController.view animated:YES];
    
    Location *location = nil;
    if (self.locationToEdit != nil) {
        hudView.text = @"Updated";
        location = self.locationToEdit;
    }else{
        hudView.text = @"Tagged";
        location = [NSEntityDescription
                    insertNewObjectForEntityForName:@"Location"
                    inManagedObjectContext:self.managedObjectContext];
        location.photoId = @-1;
    }

    location.locationDescription = _descriptionText;
    location.category = _categoryName;
    location.latitude = @(self.coordinate.latitude);
    location.longitude = @(self.coordinate.longitude);
    location.date = _date;
    location.placemark = self.placemark;
    
    if (_image != nil) {
        //in other words, when the user has picked a photo.
        if (![location hasPhoto]) {
            location.photoId = @([Location nextPhotoId]);
        }
        NSData *data = UIImageJPEGRepresentation(_image, 0.5);
        NSError *error;
        if (![data writeToFile:[location photoPath] options:NSDataWritingAtomic error:&error]) {
            NSLog(@"Error writing file: %@", error);
        }
    }
    
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        FATAL_CORE_DATA_ERROR(error);
        return;
    }
    
    [self performSelector:@selector(closeScreen) withObject:nil afterDelay:0.6];
}

- (IBAction)cancel:(id)sender
{
    [self closeScreen];
}

- (IBAction)categoryPickerDidPickCategory:(UIStoryboardSegue *)segue
{
    CategoryPickerViewController *viewController = segue.sourceViewController;
    _categoryName = viewController.selectedCategoryName;
    self.categoryLabel.text = _categoryName;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"PickCategory"]) {
        CategoryPickerViewController *controller = segue.destinationViewController;
        controller.selectedCategoryName = _categoryName;
    }
}

- (void)closeScreen
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.locationToEdit != nil) {
        self.title = @"Edit Location";
        
        if ([self.locationToEdit hasPhoto]) {
            UIImage *existingImage = [self.locationToEdit photoImage];
            if (existingImage != nil) {
                //The call to if (existingImage != nil) is a bit of defensive programming.
                [self showImage:existingImage];
            }
        }
    }
    
    self.descriptionTextView.text = _descriptionText;
    self.categoryLabel.text = _categoryName;
    self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", self.coordinate.latitude];
    self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", self.coordinate.longitude];
    
    if (self.placemark != nil) {
        self.addressLabel.text = [self stringFromPlacemark:self.placemark];
    }else{
        self.addressLabel.text = @"No Address Found";
    }
    self.dateLabel.text = [self formatDate:_date];
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
    gestureRecognizer.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:gestureRecognizer];
    
    //Changes the colors of the table view (but not the cells) and some of the other controls.
    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0f alpha:0.2f];
    
    self.descriptionTextView.textColor = [UIColor whiteColor];
    self.descriptionTextView.backgroundColor = [UIColor blackColor];
    
    self.photoLabel.textColor = [UIColor whiteColor];
    self.photoLabel.highlightedTextColor = self.photoLabel.textColor;
    
    self.addressLabel.textColor = [UIColor colorWithWhite:1.0f alpha:0.4f];
    self.addressLabel.highlightedTextColor = self.addressLabel.textColor;

}

- (void)showImage:(UIImage *)image
{
    self.imageView.image = image;
    self.imageView.hidden = NO;
    self.imageView.frame = CGRectMake(10, 10, 260, 260 * [self imageAspectRatio:image]);
    self.photoLabel.hidden = YES;
}

- (void)setLocationToEdit:(Location *)newLocationToEdit
{
    if (_locationToEdit != newLocationToEdit) {
        _locationToEdit = newLocationToEdit;
        
        _descriptionText = _locationToEdit.locationDescription;
        _categoryName = _locationToEdit.category;
        _date = _locationToEdit.date;
        self.coordinate = CLLocationCoordinate2DMake([_locationToEdit.latitude doubleValue], [_locationToEdit.longitude doubleValue]);
        self.placemark = _locationToEdit.placemark;
        
    }
}

- (void)hideKeyboard:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:point];
    if (indexPath != nil && indexPath.section == 0 && indexPath.row == 0) {
        return;
    }
    [self.descriptionTextView resignFirstResponder];
}

- (NSString *)stringFromPlacemark:(CLPlacemark *)placemark
{
    NSMutableString *line = [NSMutableString stringWithCapacity:100];
    
    [line addText:placemark.subThoroughfare withSeparator:@""];
    [line addText:placemark.thoroughfare withSeparator:@" "];
    [line addText:placemark.locality withSeparator:@", "];
    [line addText:placemark.administrativeArea withSeparator:@", "];
    [line addText:placemark.postalCode withSeparator:@" "];
    [line addText:placemark.country withSeparator:@", "];
    
    return line;
}

- (NSString *)formatDate:(NSDate *)theDate
{
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    }
    return [formatter stringFromDate:theDate];
}

- (void)takePhoto
{
    _imagePicker = [[UIImagePickerController alloc] init];
    _imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    _imagePicker.delegate = self;
    _imagePicker.allowsEditing = YES;
    [self presentViewController:_imagePicker animated:YES completion:nil];
    
    //make the Cancel button appears in yellow instead of blue.
    _imagePicker.view.tintColor = self.view.tintColor;
}

- (void)choosePhotoFromLibrary
{
    _imagePicker = [[UIImagePickerController alloc] init];
    _imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    _imagePicker.delegate = self;
    _imagePicker.allowsEditing = YES;
    [self presentViewController:_imagePicker animated:YES completion:nil];
    
    //make the Cancel button appears in yellow instead of blue.
    _imagePicker.view.tintColor = self.view.tintColor;
}

- (void)showPhotoMenu
{
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        _actionSheet = [[UIActionSheet alloc]
                                      initWithTitle:nil
                                      delegate:self
                                      cancelButtonTitle:@"Cancel"
                                      destructiveButtonTitle:nil
                                      otherButtonTitles:@"Take Photo", @"Choose From Library",
                                      nil];
        [_actionSheet showInView:self.view];
    }else{
        [self choosePhotoFromLibrary];
    }
}

//when user press HOME button on this view, we need dismiss imagePicker and actionSheet.
- (void)applicationDidEnterBackground
{
    if (_imagePicker != nil) {
        [self dismissViewControllerAnimated:NO completion:nil];
        _imagePicker = nil;
    }
    if (_actionSheet != nil) {
        [_actionSheet dismissWithClickedButtonIndex:_actionSheet.cancelButtonIndex animated:NO];
        _actionSheet = nil;
    }
    //resign keyboard
    [self.descriptionTextView resignFirstResponder];
}

//my solution to the dynamic photo cell height exercise, I create the method by myself.
- (CGFloat)imageAspectRatio:(UIImage *)image
{
    return image.size.height / image.size.width;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0) {
        return 88;
    }else if (indexPath.section == 1){
        if (self.imageView.hidden) {
            return 44;
        }else{
            //my solution to the dynamic photo cell height exercise
            if (_image != nil) {
                //add new image
                return 260 * [self imageAspectRatio:_image] +20;
            }else{
                //get the old image
                return 260 * [self imageAspectRatio:[self.locationToEdit photoImage]] + 20;
            }
        }
    }else if (indexPath.section == 2 && indexPath.row == 2){
        CGRect rect = CGRectMake(100, 10, 205, 10000);
        self.addressLabel.frame = rect;
        [self.addressLabel sizeToFit];
        rect.size.height = self.addressLabel.frame.size.height;
        self.addressLabel.frame = rect;
        return self.addressLabel.frame.size.height + 20;
    }else{
        return 44;
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 || indexPath.section == 1) {
        return indexPath;
    }else{
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0) {
        [self.descriptionTextView becomeFirstResponder];
    }else if (indexPath.section == 1 && indexPath.row == 0){
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self showPhotoMenu];
    }
}

//It changes the colors of the cells and some of the other controls.
- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor blackColor];
    
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.highlightedTextColor = cell.textLabel.textColor;
    
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1.0f alpha:0.4f];
    cell.detailTextLabel.highlightedTextColor = cell.detailTextLabel.textColor;
    
    UIView *selectionView = [[UIView alloc] initWithFrame:CGRectZero];
    selectionView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.2f];
    cell.selectedBackgroundView = selectionView;
    
    //Make “Address” label visible. because this cell does not use one of the built-in cell types, so we should make a new outlet for this label.
    if (indexPath.row == 2) {
        UILabel *addressLabel = (UILabel *)[cell viewWithTag:100];
        addressLabel.textColor = [UIColor whiteColor];
        addressLabel.highlightedTextColor = addressLabel.textColor;
    }
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)text
{
    _descriptionText = [textView.text stringByReplacingCharactersInRange:range withString:text];
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    _descriptionText = textView.text;
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    _image = info[UIImagePickerControllerEditedImage];
    
    [self showImage:_image];
    [self.tableView reloadData];
    
    [self dismissViewControllerAnimated:YES completion:nil];
    //you must set the _imagePicker variable to nil when the imagePicker is dismissed. Otherwise you’ll be keeping a reference to an imagePicker that is no longer in use.
    _imagePicker = nil;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
    _imagePicker = nil;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet
didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [self takePhoto];
    }else if(buttonIndex == 1){
        [self choosePhotoFromLibrary];
    }
    //you must set the _actionSheet variable to nil when the action sheet is dismissed. Otherwise you’ll be keeping a reference to an action sheet that is no longer in use.
    _actionSheet = nil;
}

@end
