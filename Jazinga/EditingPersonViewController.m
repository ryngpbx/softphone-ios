//
//  EditingPersonViewController.m
//  Jazinga
//
//  Created by John Mah on 12-07-23.
//  Copyright (c) 2012 Jazinga. All rights reserved.
//

#import "EditingPersonViewController.h"

@implementation EditingPersonViewController

@synthesize editingPersonViewDelegate;

-(void) viewDidLoad {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" 
                                                                             style:UIBarButtonItemStylePlain 
                                                                            target:self 
                                                                            action:@selector(cancel)];
}

// Override setter to show/hide toolbar
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    // call super
    [super setEditing:editing animated:animated];
    
    self.navigationController.toolbarHidden = editing;
    if (editing == NO) {
        [self done];
    }
}

// Cancel button callback (does not invoke setEditing:animated)
- (void)cancel {
    // rollback edit changes
    ABAddressBookRevert(self.addressBook);
    [self dismissModalViewControllerAnimated:YES];
    
    // notify delegate
    [self.editingPersonViewDelegate editingPersonViewController:self 
                                               cancelledEditing:self.displayedPerson];
}

- (void)done {
    // commit changes
    CFErrorRef error = nil;
    if (ABAddressBookHasUnsavedChanges(self.addressBook) == YES)
        ABAddressBookSave(self.addressBook, &error);
    
    [self dismissModalViewControllerAnimated:YES];
    
    // notify delegate
    [self.editingPersonViewDelegate editingPersonViewController:self 
                                                finishedEditing:self.displayedPerson];
}

@end

@implementation EditingContactCardController

-(void) viewDidLoad {
}

// Override setter to show/hide toolbar
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    // call super
    [super setEditing:editing animated:animated];
    
    self.navigationController.toolbarHidden = YES;
    if (editing == NO) {
        [self done];
    }
}

// Cancel button callback (does not invoke setEditing:animated)
- (void)cancel {
    // rollback edit changes
    ABAddressBookRevert(self.addressBook);
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // notify delegate
    [self.editingPersonViewDelegate editingPersonViewController:self 
                                               cancelledEditing:self.displayedPerson];
}

- (void)done {
    // commit changes
    CFErrorRef error = nil;
    if (ABAddressBookHasUnsavedChanges(self.addressBook) == YES)
        ABAddressBookSave(self.addressBook, &error);
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // notify delegate
    [self.editingPersonViewDelegate editingPersonViewController:self 
                                                finishedEditing:self.displayedPerson];
}

@end