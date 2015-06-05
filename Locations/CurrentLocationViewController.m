//
//  FirstViewController.m
//  Locations
//
//  Created by 陈旭 on 5/20/15.
//  Copyright (c) 2015 陈旭. All rights reserved.
//

#import "CurrentLocationViewController.h"
#import "LocationDetailsViewController.h"
#import "NSMutableString+AddText.h"
#import <AudioToolbox/AudioServices.h>

@interface CurrentLocationViewController ()<UITabBarControllerDelegate>

@property (nonatomic, weak) IBOutlet UILabel *latitudeTextLabel;
@property (nonatomic, weak) IBOutlet UILabel *longitudeTextLabel;
@property (nonatomic, weak) IBOutlet UIView *containerView;

@end

@implementation CurrentLocationViewController
{
    CLLocationManager *_locationManager;
    CLLocation *_location;
    BOOL _updatingLocation;
    NSError *_lastLocationError;
    
    CLGeocoder *_geocoder;
    CLPlacemark *_placemark;
    BOOL _performingReverseGeocoding;
    NSError *_lastGeocodingError;
    
    UIButton *_logoButton;
    BOOL _logoVisible;
    
    UIActivityIndicatorView *_spinner;
    SystemSoundID _soundID;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        _locationManager = [[CLLocationManager alloc] init];
        _geocoder = [[CLGeocoder alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // ** Don't forget to add NSLocationAlwaysUsageDescription in MyApp-Info.plist and give it a string
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    if ([_locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [_locationManager requestAlwaysAuthorization];
    }
    
    self.tabBarController.delegate = self;
    self.tabBarController.tabBar.translucent = NO;
    [self loadSoundEffect];
}

//By the time viewWillLayoutSubviews is called, the final height of the view is known, so this is a safe place to calculate the position for the _logoButton. The moral of this story: you cannot depend on the main view’s size in viewDidLoad.
- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self updateLabels];
    [self configureGetButton];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)getLocation:(id)sender
{
    if (_logoVisible) {
        [self hideLogoView];
    }
    
    if (_updatingLocation) {
        [self stopLocationManager];
    }else{
        _location = nil;
        _lastLocationError = nil;
        _placemark = nil;
        _lastGeocodingError = nil;
        
        [self startLocalManager];
    }
    
    [self updateLabels];
    [self configureGetButton];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"TagLocation"]) {
        UINavigationController *navigationController = segue.destinationViewController;
        LocationDetailsViewController *controller = (LocationDetailsViewController *)navigationController.topViewController;
        controller.coordinate = _location.coordinate;
        controller.placemark = _placemark;
        controller.managedObjectContext = self.managedObjectContext;
    }
}

- (NSString *)stringFromPlacemark:(CLPlacemark *)thePlacemark
{
    NSMutableString *line1 = [NSMutableString stringWithCapacity:100];
    [line1 addText:thePlacemark.subThoroughfare withSeparator:@""];
    [line1 addText:thePlacemark.thoroughfare withSeparator:@" "];
    
    NSMutableString *line2 = [NSMutableString stringWithCapacity:100];
    [line2 addText:thePlacemark.locality withSeparator:@""];
    [line2 addText:thePlacemark.administrativeArea withSeparator:@" "];
    [line2 addText:thePlacemark.postalCode withSeparator:@" "];
    
    if ([line1 length] == 0) {
        //This will force the UILabel to always draw two lines of text, even if the second one looks empty (it only has a space).
        [line2 appendString:@"\n "];
        return line2;
    }else{
        [line1 appendString:@"\n"];
        [line1 appendString:line2];
        return line1;
    }
}

- (void)updateLabels
{
    if (_location != nil) {
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", _location.coordinate.latitude];
        self.longitudeLable.text = [NSString stringWithFormat:@"%.8f", _location.coordinate.longitude];
        self.tagButton.hidden = NO;
        self.messageLabel.text = @"";
        
        if (_placemark != nil) {
            self.addressLabel.text = [self stringFromPlacemark:_placemark];
        }else if(_performingReverseGeocoding){
            self.addressLabel.text = @"Searching for Address...";
        }else if (_lastGeocodingError != nil){
            self.addressLabel.text = @"Error Finding Address";
        }else{
            self.addressLabel.text = @"No Address Found";
        }
        
        self.latitudeTextLabel.hidden = NO;
        self.longitudeTextLabel.hidden = NO;
        
    }else{
        self.latitudeLabel.text = @"";
        self.longitudeLable.text = @"";
        self.addressLabel.text = @"";
        self.tagButton.hidden = YES;
        
        NSString *statusMessage;
        if (_lastLocationError != nil) {
            if ([_lastLocationError.domain isEqualToString:kCLErrorDomain] && _lastLocationError.code == kCLErrorDenied) {
                statusMessage = @"Location Services Disabled";
            }else{
                statusMessage = @"Error get Location";
            }
        }else if (![CLLocationManager locationServicesEnabled]){
            statusMessage = @"Location Services Disabled";
        }else if (_updatingLocation){
            statusMessage = @"Searching...";
        }else{
            // the logo appear when there are no coordinates or error messages to display. That’s also the state at startup time
            statusMessage = @"";
            [self showLogoView];
        }
        
        self.messageLabel.text = statusMessage;
        
        self.latitudeTextLabel.hidden = YES;
        self.longitudeTextLabel.hidden = YES;
    }
}

- (void)configureGetButton
{
    if (_updatingLocation) {
        [self.getButton setTitle:@"Stop" forState:UIControlStateNormal];
        
        //Adding an activity indicator
        if (_spinner == nil) {
            _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            _spinner.center = CGPointMake(self.messageLabel.center.x, self.messageLabel.center.y + _spinner.bounds.size.height / 2.0f + 15.0f);
            [_spinner startAnimating];
            [self.containerView addSubview:_spinner];
        }
        
    }else{
        [self.getButton setTitle:@"Get My Location" forState:UIControlStateNormal];
        
        //delete the activity indicator
        [_spinner removeFromSuperview];
        _spinner = nil;
    }
}

- (void)startLocalManager
{
    if ([CLLocationManager locationServicesEnabled]) {
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        [_locationManager startUpdatingLocation];
        _updatingLocation = YES;
        
        [self performSelector:@selector(didTimeOut:) withObject:nil afterDelay:60];
    }
}

- (void)stopLocationManager
{
    if (_updatingLocation) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didTimeOut:) object:nil];
        
        [_locationManager stopUpdatingLocation];
        _locationManager.delegate = nil;
        _updatingLocation = NO;        
    }
}

- (void)didTimeOut:(id)obj
{
    NSLog(@"*** Time out");
    
    if (_location == nil) {
        [self stopLocationManager];
        _lastGeocodingError = [NSError errorWithDomain:@"MyLocationErrorDomain" code:1 userInfo:nil];
        [self updateLabels];
        [self configureGetButton];
    }
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError %@", error);
    if (error.code == kCLErrorLocationUnknown) {
        return;
    }
    [self stopLocationManager];
    _lastLocationError = error;
    
    [self updateLabels];
    [self configureGetButton];
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations
{
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"didUpdateLocation %@", newLocation);
    
    if ([newLocation.timestamp timeIntervalSinceNow] < -5.0) {
        return;
    }
    
    if (newLocation.horizontalAccuracy < 0) {
        return;
    }
    
    CLLocationDistance distance = MAXFLOAT;
    if (_location != nil) {
        distance = [newLocation distanceFromLocation:_location];
    }
    
    if (_location == nil || _location.horizontalAccuracy > newLocation.horizontalAccuracy) {
        _lastLocationError = nil;
        _location = newLocation;
        [self updateLabels];
        
        if (newLocation.horizontalAccuracy <= _locationManager.desiredAccuracy) {
            NSLog(@"*** We are done!");
            [self stopLocationManager];
            [self configureGetButton];
            
            if (distance > 0) {
                _performingReverseGeocoding = NO;
            }
        }
        
        if (!_performingReverseGeocoding) {
            NSLog(@"*** Going to geocode");
            _performingReverseGeocoding = YES;
            
            [_geocoder reverseGeocodeLocation:_location
                            completionHandler:
             ^(NSArray *placemarks, NSError *error) {
                 NSLog(@"*** Found placemarks: %@, error: %@", placemarks, error);
                 _lastGeocodingError = error;
                 if (error == nil && [placemarks count] > 0) {
                     //check if it is the first time you’ve reverse geocoded an address.
                     if (_placemark == nil) {
                         NSLog(@"FIRST TIME!");
                         [self playSoundEffect];
                     }
                     _placemark = [placemarks lastObject];
                 }else{
                     _placemark = nil;
                 }
                 
                 _performingReverseGeocoding = NO;
                 [self updateLabels];
             }];
        }
    }else if (distance < 1.0){
        NSTimeInterval timeInterval = [newLocation.timestamp timeIntervalSinceDate:_location.timestamp];
        if (timeInterval > 10) {
            NSLog(@"*** Force done!");
            [self stopLocationManager];
            [self updateLabels];
            [self configureGetButton];
        }
    }
}

#pragma mark - UITabBarControllerDelegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController
shouldSelectViewController:(UIViewController *)viewController
{
    //make the tab bar on the main screen completely black, while it remains translucent on the other screens.
    tabBarController.tabBar.translucent = (viewController != self);
    return YES;
}

#pragma mark - Logo View

- (void)showLogoView
{
    if (_logoVisible) {
        return;
    }
    _logoVisible = YES;
    self.containerView.hidden = YES;
    
    _logoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_logoButton setBackgroundImage:[UIImage imageNamed:@"Logo"] forState:UIControlStateNormal];
    [_logoButton sizeToFit];
    [_logoButton addTarget:self action:@selector(getLocation:) forControlEvents:UIControlEventTouchUpInside];
    //49.0f is the height of the tab bar
    _logoButton.center = CGPointMake(self.view.bounds.size.width / 2.0f, self.view.bounds.size.height / 2.0f - 49.0f);
    
    [self.view addSubview:_logoButton];
}

//This creates three animations that are played at the same time
- (void)hideLogoView
{
    if (!_logoVisible) {
        return;
    }
    
    _logoVisible = NO;
    self.containerView.hidden = NO;
    
    //1) the containerView is placed outside the screen (somewhere on the right) and moved to the center
    self.containerView.center = CGPointMake(self.view.bounds.size.width * 2.0f, 40.0f + self.containerView.bounds.size.height / 2.0f);
    
    CABasicAnimation *panelMover = [CABasicAnimation animationWithKeyPath:@"position"];
    panelMover.removedOnCompletion = NO;
    panelMover.fillMode = kCAFillModeForwards;
    panelMover.duration = 0.6;
    panelMover.fromValue = [NSValue valueWithCGPoint:self.containerView.center];
    panelMover.toValue = [NSValue valueWithCGPoint:CGPointMake(160.0f, self.containerView.center.y)];
    panelMover.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    //Because the “panelMover” animation takes longest(duration), you set a delegate on it so that you will be notified when the entire animation is over.
    panelMover.delegate = self;
    [self.containerView.layer addAnimation:panelMover forKey:@"panelMover"];
    
    //2) the logo image view slides out of the screen
    CABasicAnimation *logoMover = [CABasicAnimation animationWithKeyPath:@"position"];
    logoMover.removedOnCompletion = NO;
    logoMover.fillMode = kCAFillModeForwards;
    logoMover.duration = 0.5;
    logoMover.fromValue = [NSValue valueWithCGPoint:_logoButton.center];
    logoMover.toValue = [NSValue valueWithCGPoint:CGPointMake(-160.0f, _logoButton.center.y)];
    logoMover.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [_logoButton.layer addAnimation:logoMover forKey:@"logoMover"];
    
    //3) at the same time rotates around its center, giving the impression that it’s rolling away.
    CABasicAnimation *logoRotator = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    logoRotator.removedOnCompletion = NO;
    logoRotator.fillMode = kCAFillModeForwards;
    logoRotator.duration = 0.5;
    logoRotator.fromValue = @0.0f;
    logoRotator.toValue = @(-2.0f * M_PI);
    logoRotator.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [_logoButton.layer addAnimation:logoRotator forKey:@"logoRotator"];
}

//This cleans up after the animations and removes the logo button, as you no longer need it.
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    [self.containerView.layer removeAllAnimations];
    self.containerView.center = CGPointMake(self.view.bounds.size.width / 2.0f, 40.0f + self.containerView.bounds.size.height / 2.0f);
    
    [_logoButton.layer removeAllAnimations];
    [_logoButton removeFromSuperview];
    _logoButton = nil;
}

#pragma mark - Sound Effect
//The loadSoundEffect method loads the file Sound.caf and puts it into a new System Sound object. The specifics don’t really matter, but you end up with a reference to that object in the _soundID instance variable.

- (void)loadSoundEffect
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Sound.caf" ofType:nil];
    NSURL *fileURL = [NSURL fileURLWithPath:path isDirectory:NO];
    if (fileURL == nil) {
        NSLog(@"NSURL is nil for path: %@", path);
        return;
    }
    
    OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)fileURL, &_soundID);
    if (error != kAudioServicesNoError) {
        NSLog(@"Error code %d loading sound at path: %@", (int)error, path);
        return;
    }
    
}

- (void)unloadSoundEffect
{
    AudioServicesDisposeSystemSoundID(_soundID);
    _soundID = 0;
}

- (void)playSoundEffect
{
    AudioServicesPlaySystemSound(_soundID);
}

@end
