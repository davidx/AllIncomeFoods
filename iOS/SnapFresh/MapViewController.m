/*
 * Copyright 2012 Marco Abundo, Ysiad Ferreiras, Aaron Bannert, Jeremy Canfield and Michelle Koeth
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "MapViewController.h"
#import <AddressBookUI/AddressBookUI.h>
#import "SnapRetailer.h"

@interface MapViewController () // Class extension
@property (nonatomic, weak) IBOutlet UITableView *listView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *centerButton;
@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *segmentWrapper;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *listBarButtonItem;
@property (nonatomic, weak) IBOutlet UISegmentedControl *mapTypeSegmentedControl;
@property (nonatomic, weak) IBOutlet UIImageView *yelpLogo;
@property (nonatomic, strong) UIPopoverController *masterPopoverController;
- (IBAction)toggleListView;
@end

#pragma mark -

@implementation MapViewController

@synthesize mapView;
@synthesize listView;
@synthesize centerButton;
@synthesize searchBar = _searchBar;
@synthesize segmentWrapper;
@synthesize listBarButtonItem;
@synthesize mapTypeSegmentedControl;
@synthesize yelpLogo;
@synthesize masterPopoverController;
@synthesize delegate;
// Synthesize a read-only property named "retailers", but wire it to the member variable named "_retailers".
@synthesize retailers = _retailers;

// The SnapFresh URI
static NSString *kSnapFreshURI = @"http://snapfresh.org/retailers/nearaddy.json/?address=%@";

#pragma mark - Memory management

- (void)dealloc
{
	mapView.delegate = nil;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [segmentWrapper setCustomView:mapTypeSegmentedControl];
    
    // Create a new dispatch queue to which blocks can be submitted.
    dispatchQueue = dispatch_queue_create("com.shrtlist.snapfresh.dispatchQueue", NULL);
}

- (void)viewDidUnload
{
    // Release the dispatch queue
    dispatch_release(dispatchQueue);
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }
    else
    {
        return YES;
    }
}

#pragma mark - Implement getter

- (NSArray *)retailers
{
    return [_retailers copy];
}

#pragma mark - Target action methods

- (IBAction)centerAction:(id)sender
{
    CLLocationCoordinate2D coordinate = mapView.userLocation.coordinate;
    
    if (CLLocationCoordinate2DIsValid(coordinate))
    {
        NSString *address = mapView.userLocation.subtitle;
        
        self.searchBar.text = address;
        
        [self setAnnotationsForAddressString:address];
    }
}

- (IBAction)segmentAction:(id)sender
{
	// The segmented control was clicked, handle it here 
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    
    if ([segmentedControl selectedSegmentIndex] == 0)
	{
		[mapView setMapType:MKMapTypeStandard];
	}
	else if ([segmentedControl selectedSegmentIndex] == 1)
	{
		[mapView setMapType:MKMapTypeSatellite];
	}
	else if ([segmentedControl selectedSegmentIndex] == 2)
	{
		[mapView setMapType:MKMapTypeHybrid];
	}
}

- (IBAction)toggleListView
{
    if (listView.hidden)
    {
        [UIView transitionWithView:self.view 
                          duration:0.5 
                           options:UIViewAnimationOptionTransitionFlipFromLeft 
                        animations:^{ listView.hidden = NO; mapView.hidden = YES; yelpLogo.hidden = YES; } 
                        completion:^(BOOL finished){ listBarButtonItem.title = @"Map"; }];
    }
    else
    {
        [UIView transitionWithView:self.view 
                          duration:0.5 
                           options:UIViewAnimationOptionTransitionFlipFromRight 
                        animations:^{ listView.hidden = YES; mapView.hidden = NO; yelpLogo.hidden = NO; } 
                        completion:^(BOOL finished){ listBarButtonItem.title = @" List"; }];
    }
}

- (IBAction)showInfoView:(id)sender
{
    IASKAppSettingsViewController *appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
    [appSettingsViewController setShowCreditsFooter:NO];   // Uncomment to not display InAppSettingsKit credits for creators.
    // But we encourage you not to uncomment. Thank you!
    appSettingsViewController.showDoneButton = YES;
    appSettingsViewController.delegate = self;
    appSettingsViewController.title = NSLocalizedString(@"About", @"About");
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    else
    {
        appSettingsViewController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    [self presentModalViewController:navController animated:YES];
}

#pragma mark - Map utility methods

- (void)clearMapAnnotations
{
    NSArray *annotations = [mapView.annotations filteredArrayUsingPredicate:
                            [NSPredicate predicateWithFormat:@"!(self isKindOfClass:%@)", [MKUserLocation class]]];
    
    [mapView removeAnnotations:annotations];
}

- (void)setSearchBarAnnotation:(NSString *)text
{
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    
    [geocoder geocodeAddressString:text completionHandler:^(NSArray *placemarks, NSError *error)
    {
        if (error)
        {
            NSLog(@"Forward geocode failed with error: %@", error);
            return;
        }
        
        // Get the top result returned by the geocoder
        CLPlacemark *topResult = [placemarks objectAtIndex:0];
        
        NSString *address = ABCreateStringWithAddressDictionary(topResult.addressDictionary, NO);
        
        // Create an annotation from the placemark
        MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
        annotation.title = @"Search address";
        annotation.subtitle = address;
        annotation.coordinate = topResult.location.coordinate;

        [mapView addAnnotation:annotation];
    }];
}

#pragma mark - Parse the Snapfresh response

- (void)setAnnotationsForAddressString:(NSString *)address
{
    [self clearMapAnnotations];
    
    // Create the SnapFresh web service URI with address as a parameter
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kSnapFreshURI, 
                                       [address stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];

    UIApplication* app = [UIApplication sharedApplication];
    app.networkActivityIndicatorVisible = YES;

    // Submit a block for asynchronous execution to our dispatchQueue and return immediately.
    dispatch_async(dispatchQueue, ^{
        
        NSData *data = [NSData dataWithContentsOfURL:url];
        
        UIApplication* app = [UIApplication sharedApplication];
        app.networkActivityIndicatorVisible = NO;
        
        // Create a block that gets queued up in the main_queue, a default serial queue
        dispatch_async(dispatch_get_main_queue(), ^{
        
            if (data == nil)
            {
                self.searchBar.text = nil;
            }
            else
            {
                // Parse the SnapFresh JSON response
                NSError* error;
                NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                               options:kNilOptions
                                                                                 error:&error];
                // Get the JSON array of retailers
                NSArray *retailersJSON = [jsonResponse valueForKey:@"retailers"];
                
                _retailers = [NSMutableArray array];
                
                for (NSDictionary *jsonDictionary in retailersJSON)
                {
                    // Get the JSON dictionary of a retailer
                    NSDictionary *retailerDictionary = [jsonDictionary objectForKey:@"retailer"];
                    SnapRetailer *retailer = [[SnapRetailer alloc] initWithDictionary:retailerDictionary];
                    [_retailers addObject:retailer];
                }
                
                [mapView addAnnotations:self.retailers];
                [mapView selectAnnotation:[self.retailers objectAtIndex:0] animated:YES];
                [listView reloadData];
                [self updateVisibleMapRect];
                
                // Notify our delegate that the map has new annotations.
                [delegate annotationsDidLoad:self];
            }
        });
    });
}

#pragma mark - Update the visible map rectangle

- (void)updateVisibleMapRect
{
    MKMapRect zoomRect = MKMapRectNull;

    for (id <MKAnnotation> annotation in [self retailers])
    {
        MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
        MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0, 0);
        
        if (MKMapRectIsNull(zoomRect))
        {
            zoomRect = pointRect;
        }
        else
        {
            zoomRect = MKMapRectUnion(zoomRect, pointRect);
        }
    }
    
    [mapView setVisibleMapRect:zoomRect animated:YES];
}

#pragma mark - IASKSettingsDelegate conformance

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - UISplitViewControllerDelegate conformance

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Retailers", @"Retailers");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];

    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];

    self.masterPopoverController = nil;
}

#pragma mark - MKMapViewDelegate conformance

- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    static NSString *retailerPinID = @"com.shrtlist.retailerPin";
    static NSString *searchPinID = @"com.shrtlist.searchPin";
	
	MKPinAnnotationView *annotationView = nil;
	
	// If it's the user location, just return nil.
    if (![annotation isKindOfClass:[MKUserLocation class]])
    {
        if ([annotation isKindOfClass:[SnapRetailer class]])
        {
            // Try to dequeue an existing annotation view first
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:retailerPinID];
            
            if (!annotationView)
            {
                // If an existing annotation view was not available, create one
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:retailerPinID];
                annotationView.canShowCallout = YES;
                annotationView.pinColor = MKPinAnnotationColorGreen;
                annotationView.animatesDrop = YES;
                
                UIImageView *sfIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"snap.png"]];
                annotationView.leftCalloutAccessoryView = sfIconView;
            }
            else
            {
                annotationView.annotation = annotation;
            }
        }
        else
        {
            // Try to dequeue an existing annotation view first
            annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:searchPinID];
            
            if (!annotationView)
            {
                // If an existing annotation view was not available, create one
                annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:searchPinID];
                annotationView.canShowCallout = YES;
                annotationView.pinColor = MKPinAnnotationColorRed;
                annotationView.animatesDrop = YES;
            }
            else
            {
                annotationView.annotation = annotation;
            }
        }
	}
	
    return annotationView;
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
	static BOOL didSetRegion = NO;
    
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    
    // Reverse geocode the user's location
    // Completion handler block will be executed on the main thread.
    [geocoder reverseGeocodeLocation:userLocation.location completionHandler:^(NSArray *placemarks, NSError *error)
     {
         if (error)
         {
             NSLog(@"Reverse geocode failed with error: %@", error);
             [centerButton setEnabled:NO];
             return;
         }
         
         // Get the top result returned by the geocoder
         CLPlacemark *topResult = [placemarks objectAtIndex:0];
         
         NSString *address = ABCreateStringWithAddressDictionary(topResult.addressDictionary, NO);
         userLocation.subtitle = address;
         
         [centerButton setEnabled:YES];
         
         // Set the map's region if it's not set
         if (didSetRegion == NO)
         {
             [self setAnnotationsForAddressString:address];
             
             didSetRegion = YES;
         }
     }];
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error
{
	[centerButton setEnabled:NO];
}


#pragma mark - UITableViewDataSource conformance

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.retailers.count;
}

// Customize the appearance of table view cells
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    SnapRetailer *retailer = [self.retailers objectAtIndex:indexPath.row];
    
    // Set the cell labels with SnapFresh retailer info
    cell.textLabel.text = retailer.name;
    cell.detailTextLabel.text = retailer.address;
	
	return cell;
}

#pragma mark - UITableViewDelegate conformance

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SnapRetailer *retailer = [self.retailers objectAtIndex:indexPath.row];
    [mapView setCenterCoordinate:retailer.coordinate];
    [mapView selectAnnotation:retailer animated:NO];
    [self toggleListView];
}

#pragma mark - UISearchBarDelegate conformance

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Dismiss the keyboard if it's currently open
    if ([searchBar isFirstResponder])
    {
        [searchBar resignFirstResponder];
        [searchBar setShowsCancelButton:NO animated:YES];
    }
    
    [self setSearchBarAnnotation:searchBar.text];

    [self setAnnotationsForAddressString:searchBar.text];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
}

@end