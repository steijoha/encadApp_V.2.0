//
//  EventTableController.m
//  encadApp
//
//  Created by Bernd Fecht (encad-consulting.de) on 18.02.15.
//  Copyright (c) 2015 Bernd Fecht (encad-consulting.de). All rights reserved.
//

#import "EventTableController.h"
#import <CoreData/CoreData.h>
#import "AppDelegate.h"
#import "EventTableViewCell.h"
#import "Veranstaltung.h"
#import "PDFController.h"

@interface EventTableController ()<NSFetchedResultsControllerDelegate>{
    AppDelegate *_delegate;
    NSFetchedResultsController *_fetchedResultController;
}

@property (nonatomic, strong) NSSortDescriptor *theDescriptor;
@property (nonatomic, strong) NSString* serverPath;

@end

@implementation EventTableController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //get server path
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _serverPath = [defaults stringForKey:@"serverPath"];
    
    //Set Title
    self.navigationItem.title=@"Veranstaltungen der encad consulting";
    
    //set background
    UIImageView *imageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"background_event_bird.png"]];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    self.tableView.backgroundView = imageView;

    
    //Configurate the data-Download
    _delegate = (AppDelegate*) [[UIApplication sharedApplication]delegate];
    self.theDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"anfangs_datum" ascending:YES];
    
    [self initCoreDataFetch];
    
    // Initialize the refresh control.
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor colorWithRed:0.349f green:0.545f blue:0.992f alpha:1.00f];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self
                            action:@selector(reloadData)
                  forControlEvents:UIControlEventValueChanged];
    
    //check for empty table
    [self checkforEmptyTable];

}

-(void)checkforEmptyTable{
    id sectionInfo = [[_fetchedResultController sections] objectAtIndex:0];
    if([sectionInfo numberOfObjects] == 0){
        NSString *title = @"Das tut uns Leid!";
        NSString *message = @"Zur Zeit sind keine Veranstaltungen geplant. Schauen Sie doch einfach später noch einmal vorbei, oder fragen Sie über das Hotline-Tool die encad consulting GmbH über die kommenen Themen an.";
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
                [alert addAction:cancel];
                [self presentViewController:alert animated:YES completion:nil];
        }
        else{
                UIAlertView *alert = [[UIAlertView alloc]initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                [alert show];
        }
    }
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
 Fetch request sort by name without predicate
 */
-(NSFetchRequest *)fetchRequest{
    NSFetchRequest *theFetch = [[NSFetchRequest alloc]init];
    NSEntityDescription *theType = [NSEntityDescription entityForName:@"Veranstaltung" inManagedObjectContext:_delegate.managedObjectContext];
    theFetch.entity = theType;
    theFetch.sortDescriptors = @[self.theDescriptor];
    return theFetch;
}

-(void)reloadData{
    [_delegate runVeranstaltungScripts];
    
    [self initCoreDataFetch];
    [self.tableView reloadData];
    // End the refreshing
    if (self.refreshControl) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMM d, h:mm a"];
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
    return [[_fetchedResultController sections]count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id sectionInfo = [[_fetchedResultController sections]objectAtIndex:section];
    
    return  [sectionInfo numberOfObjects];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Veranstaltung *event = [_fetchedResultController objectAtIndexPath:indexPath];
    
    static NSString *identifier = @"eventCell";
    EventTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    // Configure the cell...
    cell.titleLabel.text=event.name;
    cell.locationLabel.text=[@"Ort: "stringByAppendingString:event.ort];
    cell.timeLabel.text=[@"Uhrzeit: " stringByAppendingString:event.uhrzeit];
    [cell setStartDateLabelText:event.anfangs_datum];
    [cell setEndDateLabelText:event.end_datum];
    NSString *urlString = [[[_serverPath stringByAppendingString:@"pdf/agenda/"] stringByAppendingString:event.name] stringByAppendingString:@".pdf"];
    NSURL *url = [NSURL URLWithString: [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [cell setAgendaWebViewWithURL: url];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    PDFController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"pdf"];
    vc.event=[_fetchedResultController objectAtIndexPath:indexPath];
    vc.backgroundPicture=@"background_event_bird.png";
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    //setup
    CGRect originalRect = cell.frame;
    cell.frame=CGRectMake(-cell.frame.size.width, cell.frame.origin.y, cell.frame.size.width, cell.frame.size.height);
    //animate
    [UIView transitionWithView:cell duration:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        cell.frame=originalRect;
    } completion:nil];
}

@end
