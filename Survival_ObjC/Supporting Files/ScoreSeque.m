//
//  ScoreSegue.m
//  Survival
//
//  Created by socas on 2021-04-05.
//

#import "ScoreSeque.h"

@implementation ScoreSeque

- (void) perform {
    UIViewController *source = (UIViewController *)self.sourceViewController;
    [source.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
