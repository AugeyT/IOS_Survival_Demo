//
//  UIStoryboardSegue+ScoreSeque.h
//  Survival
//
//  Created by socas on 2021-04-05.
//

#import <UIKit/UIKit.h>
#import "MyPopSeque.h"
NS_ASSUME_NONNULL_BEGIN

@interface UIStoryboardSegue ()


@implementation MyPopSeque

- (void) perform {
    UIViewController *source = (UIViewController *)self.sourceViewController;
    [source.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
@end

NS_ASSUME_NONNULL_END
