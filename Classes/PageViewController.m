    //
//  PageViewController.m
//  WordPress
//
//  Created by Jorge Bernal on 1/17/11.
//  Copyright 2011 WordPress. All rights reserved.
//

#import "PageViewController.h"
#import "EditPageViewController.h"
#import "Page.h"

@implementation PageViewController
/*
- (id)initWithPost:(AbstractPost *)aPost {
    if (self = [super initWithNibName:@"PostViewController-iPad" bundle:nil]) {
        self.apost = aPost;
		self.blog = self.apost.blog; //keep a reference to the blog
    }
    
    return self;
}
*/
/*
- (void)showModalEditor {
    // In some cases, textViewShouldBeginEditing gets called twice
    // Don't try to show a second modal or it crashes
    if (self.modalViewController) {
        WPLog(@"showModalEditor: already has modal");
        return;
    }
    EditPageViewController *postViewController;
	if(!self.apost) //when it was deleted
		self.apost = [Page newDraftForBlog:self.blog];
    AbstractPost *postRevision = [self.apost createRevision];
    postViewController = [[EditPageViewController alloc] initWithPost:postRevision];
    postViewController.editMode = kEditPost;
    [postViewController refreshUIForCurrentPost];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorDismissed:) name:@"PostEditorDismissed" object:postViewController];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:postViewController];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    nav.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    nav.navigationBar.tintColor = [UIColor colorWithRed:31/256.0 green:126/256.0 blue:163/256.0 alpha:1.0];
    [self presentModalViewController:nav animated:YES];
    [postViewController release];
    [nav release];
}
*/

- (void)checkForNewItem {
	if(!self.apost) //when it was deleted
		self.apost = [Page newDraftForBlog:self.blog];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CGRect frame = self.contentView.frame;
    // 93 is the height of Tags+Categories rows
    frame.origin.y -= 93;
    frame.size.height += 93;
    self.contentView.frame = frame;
}
@end
