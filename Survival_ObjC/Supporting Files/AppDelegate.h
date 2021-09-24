//
//  AppDelegate.h
//  Survival_ObjC
//
//  Created by Richard Tesch on 2021-02-06.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

