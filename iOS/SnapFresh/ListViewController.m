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

#import "ListViewController.h"
#import "SnapRetailer.h"

@implementation ListViewController

@synthesize mapViewController = _mapViewController;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    self.mapViewController = (MapViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    // Set ourselves as the mapViewController's delegate
    self.mapViewController.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (UIInterfaceOrientationIsLandscape([[UIDevice currentDevice] orientation]))
    {
        UIImage *snapLogo = [UIImage imageNamed:@"snaplogo.png"];
        self.navigationItem.titleView = [[UIImageView alloc] initWithImage:snapLogo];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }
    else
    {
        return YES;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
    {
        self.navigationItem.titleView = nil;
    }
}

#pragma mark - UITableViewDataSource conformance

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return retailers.count;
}

// Customize the appearance of table view cells
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    SnapRetailer *retailer = [retailers objectAtIndex:indexPath.row];
    
    // Set the cell labels with SnapFresh retailer info
    cell.textLabel.text = retailer.name;
    cell.detailTextLabel.text = retailer.address;
	
	return cell;
}

#pragma mark - UITableViewDelegate conformance

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SnapRetailer *retailer = [retailers objectAtIndex:indexPath.row];

    NSArray *selectedAnnotations = [NSArray arrayWithObject:retailer];
    
    MKMapView *mapView = self.mapViewController.mapView;
    
    [mapView setCenterCoordinate:retailer.coordinate animated:YES];
    [mapView setSelectedAnnotations:selectedAnnotations];
}

#pragma mark - MapViewControllerDelegate conformance

- (void)annotationsDidLoad:(MapViewController *)controller
{
    retailers = [self.mapViewController retailers];

    // Reload the data when there are new annotations on the map.
    [self.tableView reloadData];
}

@end
