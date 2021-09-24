//
//  ViewController.h
//  Survival_ObjC
//
//  Created by Richard Tesch on 2021-02-06.
//

#import <UIKit/UIKit.h>
#import "Renderer.h"
#import <AVFoundation/AVFoundation.h>
#import "HighScoreManager.h"
//@interface ViewController : UIViewController
@interface ViewController : GLKViewController
{

}
@property (weak, nonatomic) IBOutlet UIButton *NextLevelButton;
@property (weak, nonatomic) IBOutlet UIButton *ContinueToScoreButton;

@property (strong, nonatomic) IBOutlet UILabel *HighScoreTitle;
@property (strong, nonatomic) IBOutlet UIStackView *ScoresStackView;
@property (strong, nonatomic) IBOutlet UILabel *HSDate1;
@property (strong, nonatomic) IBOutlet UILabel *HSDate2;
@property (strong, nonatomic) IBOutlet UILabel *HSDate3;
@property (strong, nonatomic) IBOutlet UILabel *HSDate4;
@property (strong, nonatomic) IBOutlet UILabel *HSDate5;
@property (strong, nonatomic) IBOutlet UILabel *HSBest1;
@property (strong, nonatomic) IBOutlet UILabel *HSBest2;
@property (strong, nonatomic) IBOutlet UILabel *HSBest3;
@property (strong, nonatomic) IBOutlet UILabel *HSBest4;
@property (strong, nonatomic) IBOutlet UILabel *HSBest5;

@property (strong, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UILabel *HighScoreLabel;
@property (strong, nonatomic) IBOutlet UILabel *StatusLabel;
@property (strong, nonatomic) GLKBaseEffect* effect;


@property int pickupsCollected;
@property bool allPickupsCollected;
@property NSTimeInterval timeInterval;
@property bool start;

@end

