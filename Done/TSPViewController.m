//
//  TSPViewController.m
//  Done
//
//  Created by Bart Jacobs on 13/07/14.
//  Copyright (c) 2014 Tuts+. All rights reserved.
//

#import "TSPViewController.h"

#import <CoreData/CoreData.h>

#import "TSPToDoCell.h"
#import "TSPAddToDoViewController.h"
#import "TSPUpdateToDoViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"

@interface TSPViewController ()

@property (strong, nonatomic) NSArray *items;

@property (strong, nonatomic) NSIndexPath *selection;

@end

@implementation TSPViewController

static void *ProgressContext = &ProgressContext;

#pragma mark -
#pragma mark View Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Helpers
    __weak TSPViewController *weakSelf = self;
    
    // Show Progress HUD
    [SVProgressHUD showWithStatus:@"Fetching Data" maskType:SVProgressHUDMaskTypeGradient];
    
    // Initialize Fetch Request
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"TSPItem"];
    
    // Add Sort Descriptors
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    
    // Initialize Asynchronous Fetch Request
    NSAsynchronousFetchRequest *asynchronousFetchRequest = [[NSAsynchronousFetchRequest alloc] initWithFetchRequest:fetchRequest completionBlock:^(NSAsynchronousFetchResult *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Dismiss Progress HUD
            [SVProgressHUD dismiss];
            
            // Process Asynchronous Fetch Result
            [weakSelf processAsynchronousFetchResult:result];
            
            // Remove Observer
            [result.progress removeObserver:weakSelf forKeyPath:@"completedUnitCount" context:ProgressContext];
        });
    }];
    
    // Execute Asynchronous Fetch Request
    [self.managedObjectContext performBlock:^{
        // Create Progress
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
        
        // Become Current
        [progress becomeCurrentWithPendingUnitCount:1];
        
        // Execute Asynchronous Fetch Request
        NSError *asynchronousFetchRequestError = nil;
        NSAsynchronousFetchResult *asynchronousFetchResult = (NSAsynchronousFetchResult *)[weakSelf.managedObjectContext executeRequest:asynchronousFetchRequest error:&asynchronousFetchRequestError];
        
        if (asynchronousFetchRequestError) {
            NSLog(@"Unable to execute asynchronous fetch result.");
            NSLog(@"%@, %@", asynchronousFetchRequestError, asynchronousFetchRequestError.localizedDescription);
        }
        
        // Add Observer
        [asynchronousFetchResult.progress addObserver:self forKeyPath:@"completedUnitCount" options:NSKeyValueObservingOptionNew context:ProgressContext];
        
        // Resign Current
        [progress resignCurrent];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"addToDoViewController"]) {
        // Obtain Reference to View Controller
        UINavigationController *nc = (UINavigationController *)[segue destinationViewController];
        TSPAddToDoViewController *vc = (TSPAddToDoViewController *)[nc topViewController];
        
        // Configure View Controller
        [vc setManagedObjectContext:self.managedObjectContext];
        
    } else if ([segue.identifier isEqualToString:@"updateToDoViewController"]) {
        // Obtain Reference to View Controller
        TSPUpdateToDoViewController *vc = (TSPUpdateToDoViewController *)[segue destinationViewController];
        
        // Configure View Controller
        [vc setManagedObjectContext:self.managedObjectContext];
        
        if (self.selection) {
            // Fetch Record
            NSManagedObject *record = [self.items objectAtIndex:self.selection.row];
            
            if (record) {
                [vc setRecord:record];
            }
            
            // Reset Selection
            [self setSelection:nil];
        }
    }
}

#pragma mark -
#pragma mark Table View Data Source Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.items ? 1 : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items ? self.items.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TSPToDoCell *cell = (TSPToDoCell *)[tableView dequeueReusableCellWithIdentifier:@"ToDoCell" forIndexPath:indexPath];
    
    // Configure Table View Cell
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(TSPToDoCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    // Fetch Record
    NSManagedObject *record = [self.items objectAtIndex:indexPath.row];
    
    // Update Cell
    [cell.nameLabel setText:[record valueForKey:@"name"]];
    [cell.doneButton setSelected:[[record valueForKey:@"done"] boolValue]];
    
    [cell setDidTapButtonBlock:^{
        BOOL isDone = [[record valueForKey:@"done"] boolValue];
        
        // Update Record
        [record setValue:@(!isDone) forKey:@"done"];
    }];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *record = [self.items objectAtIndex:indexPath.row];
        
        if (record) {
            [self.managedObjectContext deleteObject:record];
        }
    }
}

#pragma mark -
#pragma mark Table View Delegate Methods
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Store Selection
    [self setSelection:indexPath];
    
    // Perform Segue
    [self performSegueWithIdentifier:@"updateToDoViewController" sender:self];
}

#pragma mark -
#pragma mark Key Value Observing
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == ProgressContext) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Create Status
            NSString *status = [NSString stringWithFormat:@"Fetched %li Records", (long)[[change objectForKey:@"new"] integerValue]];
            
            // Show Progress HUD
            [SVProgressHUD setStatus:status];
        });
    }
}

#pragma mark -
#pragma mark Helper Methods
- (void)processAsynchronousFetchResult:(NSAsynchronousFetchResult *)asynchronousFetchResult {
    if (asynchronousFetchResult.finalResult) {
        // Update Items
        [self setItems:asynchronousFetchResult.finalResult];
        
        // Reload Table View
        [self.tableView reloadData];
    }
}

@end
