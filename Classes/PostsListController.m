#import "PostsListController.h"

#import "BlogDataManager.h"
#import "DraftsListController.h"
#import "LocalDraftsTableViewCell.h"
#import "PostViewController.h"
#import "PostDetailEditController.h"
#import "PostTableViewCell.h"
#import "Reachability.h"
#import "WordPressAppDelegate.h"
#import "WPNavigationLeftButtonView.h"
#import "UIViewController+WPAnimation.h"

#define NEW_VERSION_ALERT_TAG   5111

#define LOCAL_DRAFTS_ROW        0
#define POST_ROW                1

#define REFRESH_BUTTON_HEIGHT   50

@interface PostsListController (Private)
- (void)showAddPostView;
- (void)refreshHandler;
- (void)downloadRecentPosts;
- (UITableViewCell *)postCell:(UITableView *)tableView forRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)handleAutoSavedContext:(NSInteger)tag;
- (void)addRefreshButton;
@end

@implementation PostsListController

@synthesize newButtonItem, postDetailViewController, postDetailEditController;

#pragma mark -
#pragma mark Memory Management

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"kNetworkReachabilityChangedNotification" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"AsynchronousPostIsPosted" object:nil];
	
	[postDetailEditController release];
	[PostViewController release];
	
	[newButtonItem release];
	[refreshButton release];
    
	[super dealloc];
}

- (void)didReceiveMemoryWarning {
	WPLog(@"%@ %@", self, NSStringFromSelector(_cmd));
	[super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark View Lifecycle

- (void)viewDidLoad {
	[super viewDidLoad];
	
    self.tableView.backgroundColor = kTableBackgroundColor;
    
    [self addRefreshButton];
    
	// Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the
    // method "reachabilityChanged" will be called. 
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:@"kNetworkReachabilityChangedNotification" object:nil];	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePostsTableViewAfterPostSaved:) name:@"AsynchronousPostIsPosted" object:nil];
	
	newButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
																  target:self
																  action:@selector(showAddPostView)];
}

- (void)viewWillAppear:(BOOL)animated {
	BlogDataManager *dm = [BlogDataManager sharedDataManager];
	[dm postTitlesForBlog:[dm currentBlog]];
	dm.isLocaDraftsCurrent = NO;
	[dm loadPostTitlesForCurrentBlog];
	
	connectionStatus = ([[Reachability sharedReachability] remoteHostStatus] != NotReachable);
	
	[self.tableView reloadData];
	
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self handleAutoSavedContext:0];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	
	if ([delegate isAlertRunning] == YES)
		return NO;
	
	// Return YES for supported orientations
	return YES;
}

#pragma mark -

- (void)addRefreshButton {
    CGRect frame = CGRectMake(0, 0, self.tableView.bounds.size.width, REFRESH_BUTTON_HEIGHT);
	
	refreshButton = [[RefreshButtonView alloc] initWithFrame:frame];
    [refreshButton addTarget:self action:@selector(refreshHandler) forControlEvents:UIControlEventTouchUpInside];
	
    self.tableView.tableHeaderView = refreshButton;
}

- (void)showAddPostView {
	// Set current post to a new post
	// Detail view will bind data into this instance and call save
	
	[[BlogDataManager sharedDataManager] makeNewPostCurrent];
	
	self.postDetailViewController.mode = 0; 
	
	// Create a new nav controller to provide navigation bar with Cancel and Done buttons.
	// Ask for modal presentation
    WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate.navigationController pushViewController:self.postDetailViewController animated:YES];
}

- (PostViewController *)postDetailViewController {
	if (postDetailViewController == nil) {
		postDetailViewController = [[PostViewController alloc] initWithNibName:@"PostViewController" bundle:nil];
		postDetailViewController.postsListController = self;
	}
    
	return postDetailViewController;
}

#pragma mark -
#pragma mark Table View Delegate Methods

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor whiteColor];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [[BlogDataManager sharedDataManager] countOfPostTitles] + 1;
}

- (UITableViewCell *)localDraftsCell:(UITableView *)tableView forRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"DraftsCell";
    LocalDraftsTableViewCell *cell = (LocalDraftsTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    BlogDataManager *dm = [BlogDataManager sharedDataManager];
    
    if (cell == nil) {
		cell = [[[LocalDraftsTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSNumber *count = [dm.currentBlog valueForKey:@"kDraftsCount"];
    
    if ([count intValue]) {
        int c = (count == nil ? 0 : [count intValue]);
        cell.badgeLabel.text = [NSString stringWithFormat:@"(%d)", c];
    } else {
        cell.badgeLabel.text = [NSString stringWithFormat:@""];
    }
    
    return cell;
}

- (UITableViewCell *)postCell:(UITableView *)tableView forRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PostCell";
    PostTableViewCell *cell = (PostTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    BlogDataManager *dm = [BlogDataManager sharedDataManager];
    
    if (cell == nil) {
        cell = [[[PostTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
    }
    
    if ([dm countOfPostTitles]) {
        id currentPost = [dm postTitleAtIndex:indexPath.row - POST_ROW];
		cell.post = currentPost;
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == LOCAL_DRAFTS_ROW) {
		return [self localDraftsCell:tableView forRowAtIndexPath:indexPath];
	} else {
		return [self postCell:tableView forRowAtIndexPath:indexPath];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BlogDataManager *dataManager = [BlogDataManager sharedDataManager];
	dataManager.isLocaDraftsCurrent = (indexPath.row == LOCAL_DRAFTS_ROW);
	WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	
	if (indexPath.row == LOCAL_DRAFTS_ROW) {
		DraftsListController *draftsListController = [[DraftsListController alloc] initWithNibName:@"DraftsList" bundle:nil];
		draftsListController.postsListController = self;
		
		[dataManager loadDraftTitlesForCurrentBlog];
		
        [self.navigationController pushViewController:draftsListController animated:YES];
        
		[draftsListController release];
	} else {
        if (!connectionStatus) {
            UIAlertView *alert1 = [[UIAlertView alloc] initWithTitle:@"No connection to host."
                                                             message:@"Editing is not supported now."
                                                            delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            alert1.tag=NEW_VERSION_ALERT_TAG;
            [alert1 show];
            [delegate setAlertRunning:YES];
            
            [alert1 release];		
            
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }
		
        id currentPost = [dataManager postTitleAtIndex:indexPath.row - POST_ROW];
        //code to return the selection if row is in middle of saving data.
		if([[currentPost valueForKey:kAsyncPostFlag] intValue]==1)
            return;
        
		[dataManager makePostAtIndexCurrent:indexPath.row - POST_ROW];
		
		self.navigationItem.rightBarButtonItem = nil;
		self.postDetailViewController.hasChanges = NO; 
		self.postDetailViewController.mode = 1; 
		postDetailEditController.postDetailViewController=self.postDetailViewController;
		
        [delegate.navigationController pushViewController:self.postDetailViewController animated:YES];
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == LOCAL_DRAFTS_ROW) {
		return LOCAL_DRAFTS_ROW_HEIGHT;
	} else {
        return POST_ROW_HEIGHT;
    }
}

- (void)goToHome:(id)sender {
    [[BlogDataManager sharedDataManager] resetCurrentBlog];
	[self popTransition:self.navigationController.view];
}

- (void)reachabilityChanged {
	connectionStatus = ( [[Reachability sharedReachability] remoteHostStatus] != NotReachable );
	
	[self.tableView reloadData];
}

- (BOOL)handleAutoSavedContext:(NSInteger)tag {
	if ([[BlogDataManager sharedDataManager] makeAutoSavedPostCurrentForCurrentBlog]) {
		NSString *title = [[BlogDataManager sharedDataManager].currentPost valueForKey:@"title"];
		title = ( title == nil ? @"" : title );
		NSString * titleStr = [NSString stringWithFormat:@"Your last session was interrupted. Unsaved edits to the post \"%@\" were recovered.", title];
		UIAlertView *alert1 = [[UIAlertView alloc] initWithTitle:@"Recovered Post"
														 message:titleStr
														delegate:self 
											   cancelButtonTitle:nil
											   otherButtonTitles:@"Review Post", nil];
		
		alert1.tag = tag;
		
		[alert1 show];
		WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
		[delegate setAlertRunning:YES];
		
		[alert1 release];
		return YES;
	}
	
	return NO;
}

- (void)refreshHandler {
	[refreshButton startAnimating];
	[self performSelectorInBackground:@selector(downloadRecentPosts) withObject:nil];
}

- (void)downloadRecentPosts {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BlogDataManager *dm = [BlogDataManager sharedDataManager];
	
    [dm syncPostsForCurrentBlog];
    [dm loadPostTitlesForCurrentBlog];
    [dm downloadAllCategoriesForBlog:[dm currentBlog]];
    
    [self.tableView reloadData];
	
	[refreshButton stopAnimating];
	[pool release];
}

- (void)updatePostsTableViewAfterPostSaved:(NSNotification *)notification {
    NSDictionary *postIdsDict=[notification userInfo];
    BlogDataManager *dm = [BlogDataManager sharedDataManager]; 
    [dm updatePostsTitlesFileAfterPostSaved:(NSMutableDictionary *)postIdsDict];
	
	//	if([[postIdsDict valueForKey:@"isCurrentPostDraft"] intValue]==1)
	//		[self.navigationController popViewControllerAnimated:YES]; 
	
	[dm loadPostTitlesForCurrentBlog];
    
	[self.tableView reloadData];	
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if( alertView.tag != NEW_VERSION_ALERT_TAG ) //When Connection Available.
	{
		[[BlogDataManager sharedDataManager] removeAutoSavedCurrentPostFile];
		self.navigationItem.rightBarButtonItem = nil;
		self.postDetailViewController.mode = 2;
		[[self navigationController] pushViewController:self.postDetailViewController animated:YES];
	}
	WordPressAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
	[delegate setAlertRunning:NO];
}

@end