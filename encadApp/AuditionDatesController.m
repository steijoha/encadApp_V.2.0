//
//  AuditionDatesController.m
//  encadApp
//
//  Created by Bernd Fecht (encad-consulting.de) on 13.02.15.
//  Copyright (c) 2015 Bernd Fecht (encad-consulting.de). All rights reserved.
//

#import "AuditionDatesController.h"
#import <CoreData/CoreData.h>
#import "AppDelegate.h"
#import "AuditionDateTableViewCell.h"
#import "Schulungstermin.h"

@interface AuditionDatesController ()<NSFetchedResultsControllerDelegate,UITableViewDataSource,UITableViewDelegate,UIToolbarDelegate>{
    AppDelegate *_delegate;
    NSFetchedResultsController *_fetchedResultController;
}

@property (nonatomic, strong) NSSortDescriptor *theDescriptor;
@property (nonatomic, strong) NSPredicate *thePredicate;
@property (weak, nonatomic) IBOutlet UITableView *auditionTableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet UIToolbar *cityToolbar;

@end

@implementation AuditionDatesController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Set Title
    self.navigationItem.title=@"Schulungen in Augsburg";
    
    //Set Delegates
    [_auditionTableView setDelegate:self];
    [_auditionTableView setDataSource:self];
    
    //Configurate the data-Download
    _delegate = (AppDelegate*) [[UIApplication sharedApplication]delegate];
    self.theDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"datum" ascending:YES];
    
    _thePredicate = [NSPredicate predicateWithFormat:@"orts_name = 'Augsburg'"];
    
    [self initCoreDataFetch];
    
    // Initialize the refresh control
    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.backgroundColor = [UIColor purpleColor];
    _refreshControl.tintColor = [UIColor whiteColor];
    [_refreshControl addTarget:self
                            action:@selector(reloadData)
                  forControlEvents:UIControlEventValueChanged];
    
    [self.auditionTableView addSubview:_refreshControl];
    
    //Initalize the Toolbar
    UIBarButtonItem *spaceLeft = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
     UIBarButtonItem *spaceRight = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    NSArray *segItemsArray = [NSArray arrayWithObjects: @"Augsburg", @"Hamburg", nil];
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:segItemsArray];
    segmentedControl.selectedSegmentIndex=0;
    segmentedControl.tintColor=[UIColor purpleColor];
    [segmentedControl addTarget:self
                         action:@selector(changedCity:)
               forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *segmentedControlButtonItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)segmentedControl];
  
    NSArray *items = [NSArray arrayWithObjects:spaceLeft, segmentedControlButtonItem, spaceRight, nil];
    
    [_cityToolbar setItems:items];
}

-(void)changedCity:(UISegmentedControl*)segmentedControl{
    //Change predicate
    switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            _thePredicate = [NSPredicate predicateWithFormat:@"orts_name = 'Augsburg'"];
            //Change title
            self.navigationItem.title=@"Schulungen in Augsburg";
            break;
        case 1:
            _thePredicate = [NSPredicate predicateWithFormat:@"orts_name = 'Hamburg'"];
            //Change title
            self.navigationItem.title=@"Schulungen in Hamburg";
            break;
            
        default:
            break;
    }
    //reload data
    [self reloadData];
}



-(void)initCoreDataFetch{
    NSFetchRequest *request = self.fetchRequest;
    NSFetchedResultsController *theController = [[NSFetchedResultsController alloc]initWithFetchRequest:request managedObjectContext:_delegate.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    NSError *theError = nil;
    
    theController.delegate = self;
    if([theController performFetch:&theError]){
        _fetchedResultController = theController;
    }
    else{
        NSLog(@"Couldn't fetch the Result: %@", theError );
    }
}

/**
 Fetch request sort by date without predicate
 */
-(NSFetchRequest *)fetchRequest{
    NSFetchRequest *theFetch = [[NSFetchRequest alloc]init];
    NSEntityDescription *theType = [NSEntityDescription entityForName:@"Schulungstermin" inManagedObjectContext:_delegate.managedObjectContext];
    theFetch.predicate = _thePredicate;
    theFetch.entity = theType;
    theFetch.sortDescriptors = @[self.theDescriptor];
    return theFetch;
}

-(void)reloadData{
    [_delegate runSchulungsterminScripts];
    
    [self initCoreDataFetch];
    [_auditionTableView reloadData];
    // End the refreshing
    if (self.refreshControl) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMM d, HH:mm"];
        NSString *title = [NSString stringWithFormat:@"Letztes Update: %@", [formatter stringFromDate:[NSDate date]]];
        NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:[UIColor whiteColor]
                                                                    forKey:NSForegroundColorAttributeName];
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrsDictionary];
        self.refreshControl.attributedTitle = attributedTitle;
        
        [self.refreshControl endRefreshing];
    }
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return _fetchedResultController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    id sectionInfo = [[_fetchedResultController sections]objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* identifier = @"auditionDateCell";
    AuditionDateTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    // Configure the cell...
    
    Schulungstermin *auditionDate = [_fetchedResultController objectAtIndexPath:indexPath];
    cell.titleLabel.text=auditionDate.schulungs_name;
    [cell setStartDateLabelText:auditionDate.datum];
    [cell setEndDateLabelText:auditionDate.datum withDuration:[auditionDate.dauer intValue]];
    cell.softwareLabel.text=auditionDate.zusatz;
    NSString *thePDFUrl = [[@"http://www.encad-akademie.de/pdf/datasheet/" stringByAppendingString:auditionDate.datenblatt_name] stringByAppendingString:@".pdf"];
    [cell setPDF:thePDFUrl];
    
    return cell;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end