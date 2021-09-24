//
//  ViewController.m
//  Survival_ObjC
//
//  Created by Richard Tesch on 2021-02-06.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "Resources/cube.h"
#import "HighScoreManager.h"

// Constants to remove magic numbers plus repetitive math
const int NUM_TREES = 5;
const int MAX_TIMER = 30;

//===========================================================================
// --- Class interface
//
@interface ViewController () {
    // links to other classes
    Renderer *glesRenderer;
    
    // Persistant variables
    CGFloat panMoveX;
    CGFloat panMoveY;
    CGPoint touchOriginLast;
    
    // Vars requird by our timer
    NSTimer *timer;
    NSTimer *timer2;
    int timerSecond;
    int timerMillisecond;

    // High score link and vars associated with high scores
    HighScoreManager *hsMgr;
    bool showingStats;
    bool checkHighScore;
    
    // inTrapWait flag used for sync client cought in trap
    // !! This bool cannot be written to accept by a trap object !!
    bool inTrapWait;
    REN_OBJ inTrapOwner;
    
    // Used to track when the player is in sprint mode
    bool isSprinting;

    // Audio reference for playing sounds
    AVAudioPlayer *player, *playerBlood2,  *playerPowerup, *playerFluteWin, *playerItemRespawn,
                  *playerLevelCompoleted, *playerStepInGrass, *playerStepInGrass2, *playerVineGrowth, *playerTheme;
    bool playOnce;
    
    // Store all obstacle position
    bool hitObstacle;
    bool hitBorder;

    // misc vars for level, player and netforce for player
    int currentLevel;
    bool firstCallPlayer;
    GLKVector2 netForce;
}

@end


//===========================================================================
// --- Class implementation
//
@implementation ViewController

@synthesize NextLevelButton;
@synthesize ContinueToScoreButton;

// used to store reference for tree model info
struct MODEL_DATA {
    GLKVector3 pos;
    GLKVector3 rot;
    int model_id;
};

// Track tree models
struct MODEL_DATA model[NUM_TREES];

// All wsynthized properties
@synthesize pickupsCollected;
@synthesize allPickupsCollected;
@synthesize timerLabel;
@synthesize HighScoreLabel;
@synthesize StatusLabel;

// High score properties and associations
@synthesize HighScoreTitle;
@synthesize ScoresStackView;
@synthesize HSDate1;
@synthesize HSDate2;
@synthesize HSDate3;
@synthesize HSDate4;
@synthesize HSDate5;
@synthesize HSBest1;
@synthesize HSBest2;
@synthesize HSBest3;
@synthesize HSBest4;
@synthesize HSBest5;


//===========================================================================
// Method used to update the UI highscore data with high score system values
//===========================================================================
- (void) UpdateHighScoreScreen
{
    // Grab the high score list for high score system
    NSArray *hsList = [hsMgr GetHighScoreList];

    // loop through the first five (all we have on UI screen) and update UI
    for (int i = 0; i < 5 && i < hsList.count; i++)
    {
        // Create links tht are update to correct ui label based on index
        UILabel *bestToUpdate = NULL;
        UILabel *onToUpdate = NULL;

        // Pick and assign the correct UI label to current high score list entry
        switch (i)
        {
            case 0: onToUpdate = HSDate1; bestToUpdate = HSBest1; break;
            case 1: onToUpdate = HSDate2; bestToUpdate = HSBest2; break;
            case 2: onToUpdate = HSDate3; bestToUpdate = HSBest3; break;
            case 3: onToUpdate = HSDate4; bestToUpdate = HSBest4; break;
            case 4: onToUpdate = HSDate5; bestToUpdate = HSBest5; break;
        }
        
        // If we have a matching UI label proceded
        if (bestToUpdate != NULL)
        {
            // Grab the current high score list entry and update the UI data
            HSEntry *hsEntry = hsList[i];
            onToUpdate.text = hsEntry.date;
            bestToUpdate.text = [NSString stringWithFormat:@"%.1f", hsEntry.score];
        }
    }
}


//===========================================================================
// Called by system immediatly after we are instantuated to allow us to setup
//===========================================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    pickupsCollected = 0;
    allPickupsCollected = FALSE;
    
    // Set up context
    glesRenderer = [[Renderer alloc] init];
    GLKView *view = (GLKView *)self.view;
    // Set up view
    [glesRenderer setup:view];
    // Load model data
    [glesRenderer loadModels];
    
//    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
//                                                 pathForResource:@"bg_music"
//                                                 ofType:@"mp3"]];
//    player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
//    player.numberOfLoops = -1;
//    [player play];

    // Register the first level we will played
    currentLevel = 1;
    
    // Make sure that everything is init for right order
    touchOriginLast.x = 0.0f;
    touchOriginLast.y = 0.0f;
    panMoveX = 0.0f;
    panMoveY = 0.0f;
    
    // Setup timer
    [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(applyFrictionForce) userInfo:nil repeats:YES];
    
    // initialize countdown timer
    [timerLabel setText:[NSString stringWithFormat:@"Time To Beat: %d.%d", MAX_TIMER, 0]];
    timerSecond = MAX_TIMER;
    timerMillisecond = 0;
    timer=[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
    
    // init: use the high score manager to store values
    hsMgr = [[HighScoreManager alloc] init];
    if (hsMgr)
    {
        // Call setup first so we can use all other methods
        [hsMgr Setup:(float)MAX_TIMER];
        // Load the high scores
        [hsMgr LoadHighScores];
        // update the loaded scores with the UI data so they visual match
        [self UpdateHighScoreScreen];
    }
    // Show the high score selectiom button and make sure tracking var aligns with button showing
    checkHighScore = YES;
    showingStats = NO;
    
    // Hide the next level button
    NextLevelButton.hidden = YES;
    // Set a first call var
    firstCallPlayer = YES;
    
    // Sound effects
    // Library used: AVAudoplayer 
    // Finding the path where the audio is stored, with the type of the audio sepecified
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/bleep" ofType:@"mp3"]];
    // Initializing the audio from the files found
    player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    // Settings for the number of loops, -1 is infinite times
    player.numberOfLoops = 0;
    NSURL *urlBlood = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/Blood2" ofType:@"wav"]];
    playerBlood2 = [[AVAudioPlayer alloc] initWithContentsOfURL:urlBlood error:nil];
    playerBlood2.numberOfLoops = 0;
    NSURL *urlPowerup = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/powerup" ofType:@"wav"]];
    playerPowerup = [[AVAudioPlayer alloc] initWithContentsOfURL:urlPowerup error:nil];
    playerPowerup.numberOfLoops = 0;
    NSURL *urlFluteWin = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/FluteWin" ofType:@"wav"]];
    playerFluteWin = [[AVAudioPlayer alloc] initWithContentsOfURL:urlFluteWin error:nil];
    playerFluteWin.numberOfLoops = 0;
    NSURL *urlItemRespawn = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/ItemRespawn" ofType:@"wav"]];
    playerItemRespawn = [[AVAudioPlayer alloc] initWithContentsOfURL:urlItemRespawn error:nil];
    playerItemRespawn.numberOfLoops = 0;
    NSURL *urlLevelCompleted = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/LevelCompleted" ofType:@"wav"]];
    playerLevelCompoleted = [[AVAudioPlayer alloc] initWithContentsOfURL:urlLevelCompleted error:nil];
    playerLevelCompoleted.numberOfLoops = 0;
    NSURL *urlStepInGrass = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/StepInGrass (2)" ofType:@"mp3"]];
    playerStepInGrass = [[AVAudioPlayer alloc] initWithContentsOfURL:urlStepInGrass error:nil];
    playerStepInGrass.numberOfLoops = 0;
    NSURL *urlStepInGrass2 = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/StepInGrass (4)" ofType:@"mp3"]];
    playerStepInGrass2 = [[AVAudioPlayer alloc] initWithContentsOfURL:urlStepInGrass2 error:nil];
    playerStepInGrass2.numberOfLoops = 0;
    NSURL *urlVineGrowth = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/VineGrowth" ofType:@"mp3"]];
    playerVineGrowth = [[AVAudioPlayer alloc] initWithContentsOfURL:urlVineGrowth error:nil];
    playerVineGrowth.numberOfLoops = 0;
    NSURL *urlTheme = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SFX/Theme" ofType:@"mp3"]];
    playerTheme = [[AVAudioPlayer alloc] initWithContentsOfURL:urlTheme error:nil];
    playerTheme.numberOfLoops = -1;
    playerTheme.volume = 0.5f;
    
    // Initialize the sprint mode to be off when first starting
    isSprinting = false;

    // initialization of the bool inTrapWait
    inTrapWait = FALSE;
    inTrapOwner = REN_OBJ_NULL;
    
    // initialization of the bool hitObstacle and hitBorder
    hitObstacle = false;
    hitBorder = false;

    // Register for Floor object callback
    SEL selFloor = @selector(onUpdateReqFloor);
    [glesRenderer registerUpdate:REN_OBJ_GROUND_PLANE theUpdatefunc:(SEL)selFloor fromObject:(id) self];

    // Register for Trap object callbacks
    SEL selTrap = @selector(onUpdateReqTrap1);
    [glesRenderer registerUpdate:REN_OBJ_TRAP_1 theUpdatefunc:(SEL)selTrap fromObject:(id) self];
    SEL selTrap2 = @selector(onUpdateReqTrap2);
    [glesRenderer registerUpdate:REN_OBJ_TRAP_2 theUpdatefunc:(SEL)selTrap2 fromObject:(id) self];
    SEL selTrap3 = @selector(onUpdateReqTrap3);
    [glesRenderer registerUpdate:REN_OBJ_TRAP_3 theUpdatefunc:(SEL)selTrap3 fromObject:(id) self];
    SEL selTrap4 = @selector(onUpdateReqTrap4);
    [glesRenderer registerUpdate:REN_OBJ_TRAP_4 theUpdatefunc:(SEL)selTrap4 fromObject:(id) self];
    SEL selTrap5 = @selector(onUpdateReqTrap5);
    [glesRenderer registerUpdate:REN_OBJ_TRAP_5 theUpdatefunc:(SEL)selTrap5 fromObject:(id) self];
 
    // Register for Obsatcle object callbacks
    SEL selObstacle1 = @selector(onUpdateReqObstacle1);
    [glesRenderer registerUpdate:REN_OBJ_OBSTACLE_1 theUpdatefunc:(SEL)selObstacle1 fromObject:(id) self];
    SEL selObstacle2 = @selector(onUpdateReqObstacle2);
    [glesRenderer registerUpdate:REN_OBJ_OBSTACLE_2 theUpdatefunc:(SEL)selObstacle2 fromObject:(id) self];
    SEL selObstacle3 = @selector(onUpdateReqObstacle3);
    [glesRenderer registerUpdate:REN_OBJ_OBSTACLE_3 theUpdatefunc:(SEL)selObstacle3 fromObject:(id) self];
    SEL selObstacle4 = @selector(onUpdateReqObstacle4);
    [glesRenderer registerUpdate:REN_OBJ_OBSTACLE_4 theUpdatefunc:(SEL)selObstacle4 fromObject:(id) self];
    SEL selObstacle5 = @selector(onUpdateReqObstacle5);
    [glesRenderer registerUpdate:REN_OBJ_OBSTACLE_5 theUpdatefunc:(SEL)selObstacle5 fromObject:(id) self];
    
    // Register for Pickup object callbacks
    SEL sel1 = @selector(onUpdateReqPickup1);
    [glesRenderer registerUpdate:REN_OBJ_PICKUP_1 theUpdatefunc:(SEL)sel1 fromObject:(id) self];
    SEL sel2 = @selector(onUpdateReqPickup2);
    [glesRenderer registerUpdate:REN_OBJ_PICKUP_2 theUpdatefunc:(SEL)sel2 fromObject:(id) self];
    SEL sel3 = @selector(onUpdateReqPickup3);
    [glesRenderer registerUpdate:REN_OBJ_PICKUP_3 theUpdatefunc:(SEL)sel3 fromObject:(id) self];
    SEL sel4 = @selector(onUpdateReqPickup4);
    [glesRenderer registerUpdate:REN_OBJ_PICKUP_4 theUpdatefunc:(SEL)sel4 fromObject:(id) self];
    SEL sel5 = @selector(onUpdateReqPickup5);
    [glesRenderer registerUpdate:REN_OBJ_PICKUP_5 theUpdatefunc:(SEL)sel5 fromObject:(id) self];
    
    // Register for Player object callback
    SEL selPlayer = @selector(onUpdateReq_Player);
    [glesRenderer registerUpdate:REN_OBJ_PLAYER theUpdatefunc:(SEL)selPlayer fromObject:(id) self];
}

//===========================================================================
// Called by system on regular inervals (tyoically every fram update but
// don't count on it
//===========================================================================
- (void)update
{
    // Set a local flag to initiate a first call of init
    static bool firstCall = true;
    
    // Is this the first time that update has ever been called?
    if (firstCall)
    {
        // Use this opportunity to initlize improtant varaibles
        playOnce = YES;
        firstCall = false;
        // Prevent app from crashing when there is no sound found or name of the sound doesn't match
        if (playerTheme)
        {
            // Play the background music 
            [playerTheme play];
            //NSLog(@"Theme is playing");
        }
        
        // Initialize High Score UI label with the time to beat
        [HighScoreLabel setText:[NSString stringWithFormat:@"Time To Beat: %.1f", hsMgr.LowestHighScore]];
    }
    
    // Evaluate a win loose situation
    if (allPickupsCollected)
    {
        // Player has won
        StatusLabel.text = [NSString stringWithFormat:@"%s%d%s", "Stage ", currentLevel, " Complete"];
        StatusLabel.hidden = NO;
        ContinueToScoreButton.hidden = NO;
        
        if (currentLevel >= 3)
        {
            [NextLevelButton setTitle:@"Back to Stage 1" forState: normal];
        }
        else
        {
            [NextLevelButton setTitle:@"Continue" forState: normal];
        }
        
        NextLevelButton.hidden = NO;

        // Save and load HighScore
        if(playerLevelCompoleted)
        {
            if (playOnce == YES)
            {
                playOnce = NO;
                [playerLevelCompoleted play];
            }
        }
        // now save the numbers
    }
    else
    {
        // Player has lost
        StatusLabel.text = @"Death is Sweet";
        ContinueToScoreButton.hidden = NO;

        if (timerSecond <= -1)
        {
            // Player has lost
            StatusLabel.text = @"Death is Sweet";
            ContinueToScoreButton.hidden = NO;
            
            // Setup the right state of show/hide a button and the sound to play for loss
            [NextLevelButton setTitle:@"Retry" forState: normal];
            NextLevelButton.hidden = NO;
            if (playerBlood2)
            {
                if (playOnce == YES)
                {
                    playOnce = NO;
                    [playerBlood2 play];
                }
            }
        }
        else
        {
            // Setup the visibility of main buttons based on this state
            StatusLabel.hidden = YES;
            ContinueToScoreButton.hidden = YES;
            NextLevelButton.hidden = YES;
        }
    }
    
    // Call the renderer to execute the latest updates.
    [glesRenderer update];
}


//===========================================================================
// Called by system on regular inervals (tyoically every frame update but
// don't count on it
//===========================================================================
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [glesRenderer draw:rect];
}


//===========================================================================
// System callback notifer for Pan Gesture. Used to control the character
//===========================================================================
- (IBAction)aOneTouchPanGesture:(UIPanGestureRecognizer *)sender {
    // Only allow the pinch zoom action if the renderer is NOT rotating
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            break;
            
        case UIGestureRecognizerStateChanged: {
            // Using the drag direction change calculate the delta from last change
            //  to adjust the renderer x any y rotation offset
            //CGPoint touchOriginDelta = CGPointMake(touchOriginLast.x - touchOrigin.x, touchOriginLast.y - touchOrigin.y);
            // ^ Delta is not required, we can remove this after reviewed
            
            // touchOrigin determines how far the pan gesture travels from its origin
            CGPoint touchOrigin = [sender translationInView:sender.view];
            
            // calculate the unit vector of the pan gesture
            float magnitute = sqrtf(touchOrigin.x * touchOrigin.x + touchOrigin.y * touchOrigin.y);
            CGPoint unitVector = CGPointMake(touchOrigin.x / magnitute, touchOrigin.y / magnitute);
            
            // unit vector is used to determined the direction of player's movement
            panMoveX = unitVector.x;
            panMoveY = unitVector.y;
            
            // use force to move player in level 3
            if (currentLevel == 3)
            {
                [self applyMovementForce];
            }
            
            if (magnitute > 75)
            {
                isSprinting = true;
            }
            else
            {
                isSprinting = false;
            }
            
            // For debug only
//            NSLog(@"1T-Pan (%lu Finger), state %lu",
//                  (unsigned long)sender.numberOfTouches, (unsigned long)sender.state);
//
//            touchOriginLast = touchOrigin;
            }
            break;
                            
        default:
            // Must clear the last location or undesired results on first gesture notification
            touchOriginLast.x = touchOriginLast.y = 0.0f;
            panMoveX = panMoveY = 0.0f;
            break;
    }
}


#pragma mark - Update Requests
// ------- UPDATE REQUESTS ---------------------------------------------------------------------
// Pickups on the field
- (void) onUpdateReqPickup1
{
    static bool breathIn = NO;
    static bool firstCall = YES;
    static float origScale = 0.0f;
    static float hitClearTimer = 0.0f;
    
    // VERY Important!!!! Get the updat dat at start of call back. This will be your working
    // ptr to buffered values. When you are finished you can commit the values so they update!
    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_PICKUP_1];
    
    // Play it safe and always check that you have a valid pointer. It will be null if you
    // somehow submitted and invalid renderer object identifier.
    if (updateDataPtr != NULL)
    {
        if (firstCall == YES)
        {
            // On first call for this demo we gard the original scales to breath 'around'
            origScale = updateDataPtr->scale.x;
            firstCall = NO;

            // If you want to show your object the first time then you need to set
            //  the position and visible flag to ON for showing and positioning it.
            // We want collision so we turn it on.
            updateDataPtr->pos = GLKVector3Make(-0.90f, -1.5f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
        }
        
        // Determine if object should be active / visible
        if (pickupsCollected == 0)
        {
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
            glesRenderer.pickupPosX = updateDataPtr->pos.x;
            glesRenderer.pickupPosY = updateDataPtr->pos.y;
        }
        else
        {
            updateDataPtr->visible = NO;
            updateDataPtr->collision.detectionOn = FALSE;
        }
        
        // Was a collision detected?
        if (updateDataPtr->collision.isHit)
        {
            // Collision was detected so hide the object and clear hit
            updateDataPtr->visible = NO;
            updateDataPtr->collision.isHit = NO;
            pickupsCollected = 1;
            NSLog(@"Pickups Collected: %.1d", pickupsCollected);
            // want to make sure timer is accurate to the hit time
            hitClearTimer = 0.0f;
            if (playerPowerup)
            {
                [playerPowerup play];
            }
        }

        // Animate the pickup
        if (breathIn == NO)
        {
            // To breath out we increase the scale on x,y by an amount
            updateDataPtr->scale.x += 0.0015f;
            updateDataPtr->scale.y += 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = (updateDataPtr->scale.x > origScale + 0.008f);
        }
        else if (breathIn == YES)
        {
            // To breath in we decrease the scale on x,y by an amount
            updateDataPtr->scale.x -= 0.0015f;
            updateDataPtr->scale.y -= 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = !(updateDataPtr->scale.x < origScale - 0.008f);
        }
        
        // VERY IMPORTANT!! Now that the data was update you need to commit it for update
        // If you choose not to commit for whatever reason nothing changes. BUT THE DATA IS
        // NOT GUARENTEED PERSISTANT OVER UPDATES!!!
        // REMEMBER USE THE RIGHT OBJECT ID !!! for what you registered
        [glesRenderer updateCommit:REN_OBJ_PICKUP_1];
    }
}
// Pickup 2
- (void) onUpdateReqPickup2
{
    static bool breathIn = NO;
    static bool firstCall = YES;
    static float origScale = 0.0f;
    static float hitClearTimer = 0.0f;
    
    // VERY Important!!!! Get the updat dat at start of call back. This will be your working
    // ptr to buffered values. When you are finished you can commit the values so they update!
    REN_OBJ_DATA_MIN* updateDataPtr2 =[glesRenderer updateData:REN_OBJ_PICKUP_2];
    
    // Play it safe and always check that you have a valid pointer. It will be null if you
    // somehow submitted and invalid renderer object identifier.
    if (updateDataPtr2 != NULL)
    {
        if (firstCall == YES)
        {
            // On first call for this demo we gard the original scales to breath 'around'
            origScale = updateDataPtr2->scale.x;
            firstCall = NO;

            // If you want to show your object the first time then you need to set
            //  the position and visible flag to ON for showing and positioning it.
            // We want collision so we turn it on.
            updateDataPtr2->pos = GLKVector3Make(1.0f, 1.8f, 0.0f);
            updateDataPtr2->visible = YES;
            updateDataPtr2->collision.detectionOn = TRUE;
        }
        
        // Determine if object should be active / visible
        if (pickupsCollected != 1) {
            updateDataPtr2->visible = NO;
            updateDataPtr2->collision.detectionOn = FALSE;
        }
        else
        {
            updateDataPtr2->visible = YES;
            updateDataPtr2->collision.detectionOn = TRUE;
            glesRenderer.pickupPosX = updateDataPtr2->pos.x;
            glesRenderer.pickupPosY = updateDataPtr2->pos.y;
        }
        
        // Was a collision detected?
        if (updateDataPtr2->collision.isHit)
        {
            // Collision was detected so hide the object and clear hit
            updateDataPtr2->visible = NO;
            updateDataPtr2->collision.isHit = NO;
            pickupsCollected = 2;
            NSLog(@"Pickups Collected: %.1d", pickupsCollected);
            // want to make sure timer is accurate to the hit time
            hitClearTimer = 0.0f;
            if(playerPowerup)
            {
                [playerPowerup play];
            }
        }

        // Animate the pickup
        if (breathIn == NO)
        {
            // To breath out we increase the scale on x,y by an amount
            updateDataPtr2->scale.x += 0.0015f;
            updateDataPtr2->scale.y += 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = (updateDataPtr2->scale.x > origScale + 0.008f);
        }
        else if (breathIn == YES)
        {
            // To breath in we decrease the scale on x,y by an amount
            updateDataPtr2->scale.x -= 0.0015f;
            updateDataPtr2->scale.y -= 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = !(updateDataPtr2->scale.x < origScale - 0.008f);
        }
        
        // VERY IMPORTANT!! Now that the data was update you need to commit it for update
        // If you choose not to commit for whatever reason nothing changes. BUT THE DATA IS
        // NOT GUARENTEED PERSISTANT OVER UPDATES!!!
        // REMEMBER USE THE RIGHT OBJECT ID !!! for what you registered
        [glesRenderer updateCommit:REN_OBJ_PICKUP_2];
    }
}
// Pickup 3
- (void) onUpdateReqPickup3
{
    static bool breathIn = NO;
    static bool firstCall = YES;
    static float origScale = 0.0f;
    static float hitClearTimer = 0.0f;
    
    // VERY Important!!!! Get the updat dat at start of call back. This will be your working
    // ptr to buffered values. When you are finished you can commit the values so they update!
    REN_OBJ_DATA_MIN* updateDataPtr3 =[glesRenderer updateData:REN_OBJ_PICKUP_3];
    
    // Play it safe and always check that you have a valid pointer. It will be null if you
    // somehow submitted and invalid renderer object identifier.
    if (updateDataPtr3 != NULL)
    {
        if (firstCall == YES)
        {
            // On first call for this demo we gard the original scales to breath 'around'
            origScale = updateDataPtr3->scale.x;
            firstCall = NO;

            // If you want to show your object the first time then you need to set
            //  the position and visible flag to ON for showing and positioning it.
            // We want collision so we turn it on.
            updateDataPtr3->pos = GLKVector3Make(-1.2f, 1.45f, 0.0f);
            updateDataPtr3->visible = YES;
            updateDataPtr3->collision.detectionOn = TRUE;
        }
        
        // Determine if object should be active / visible
        if (pickupsCollected != 2) {
            updateDataPtr3->visible = NO;
            updateDataPtr3->collision.detectionOn = FALSE;
        }
        else
        {
            updateDataPtr3->visible = YES;
            updateDataPtr3->collision.detectionOn = TRUE;
            
            glesRenderer.pickupPosX = updateDataPtr3->pos.x;
            glesRenderer.pickupPosY = updateDataPtr3->pos.y;
        }
        
        // Was a collision detected?
        if (updateDataPtr3->collision.isHit)
        {
            // Collision was detected so hide the object and clear hit
            updateDataPtr3->visible = NO;
            updateDataPtr3->collision.isHit = NO;
            pickupsCollected = 3;
            NSLog(@"Pickups Collected: %.1d", pickupsCollected);
            // want to make sure timer is accurate to the hit time
            hitClearTimer = 0.0f;
            if(playerPowerup)
            {
                [playerPowerup play];
            }
        }

        // Animate the pickup
        if (breathIn == NO)
        {
            // To breath out we increase the scale on x,y by an amount
            updateDataPtr3->scale.x += 0.0015f;
            updateDataPtr3->scale.y += 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = (updateDataPtr3->scale.x > origScale + 0.008f);
        }
        else if (breathIn == YES)
        {
            // To breath in we decrease the scale on x,y by an amount
            updateDataPtr3->scale.x -= 0.0015f;
            updateDataPtr3->scale.y -= 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = !(updateDataPtr3->scale.x < origScale - 0.008f);
        }
        
        // VERY IMPORTANT!! Now that the data was update you need to commit it for update
        // If you choose not to commit for whatever reason nothing changes. BUT THE DATA IS
        // NOT GUARENTEED PERSISTANT OVER UPDATES!!!
        // REMEMBER USE THE RIGHT OBJECT ID !!! for what you registered
        [glesRenderer updateCommit:REN_OBJ_PICKUP_3];
    }
}
// Pickup 4
- (void) onUpdateReqPickup4
{
    static bool breathIn = NO;
    static bool firstCall = YES;
    static float origScale = 0.0f;
    static float hitClearTimer = 0.0f;
    
    // VERY Important!!!! Get the updat dat at start of call back. This will be your working
    // ptr to buffered values. When you are finished you can commit the values so they update!
    REN_OBJ_DATA_MIN* updateDataPtr4 =[glesRenderer updateData:REN_OBJ_PICKUP_4];
    
    // Play it safe and always check that you have a valid pointer. It will be null if you
    // somehow submitted and invalid renderer object identifier.
    if (updateDataPtr4 != NULL)
    {
        if (firstCall == YES)
        {
            // On first call for this demo we gard the original scales to breath 'around'
            origScale = updateDataPtr4->scale.x;
            firstCall = NO;

            // If you want to show your object the first time then you need to set
            //  the position and visible flag to ON for showing and positioning it.
            // We want collision so we turn it on.
            updateDataPtr4->pos = GLKVector3Make(0.5f, 1.0f, 0.0f);
            updateDataPtr4->visible = YES;
            updateDataPtr4->collision.detectionOn = TRUE;
        }
        
        // Determine if object should be active / visible
        if (pickupsCollected != 3) {
            updateDataPtr4->visible = NO;
            updateDataPtr4->collision.detectionOn = FALSE;
        }
        else
        {
            updateDataPtr4->visible = YES;
            updateDataPtr4->collision.detectionOn = TRUE;
            
            glesRenderer.pickupPosX = updateDataPtr4->pos.x;
            glesRenderer.pickupPosY = updateDataPtr4->pos.y;
        }
        
        // Was a collision detected?
        if (updateDataPtr4->collision.isHit)
        {
            // Collision was detected so hide the object and clear hit
            updateDataPtr4->visible = NO;
            updateDataPtr4->collision.isHit = NO;
            pickupsCollected = 4;
            NSLog(@"Pickups Collected: %.1d", pickupsCollected);
            // want to make sure timer is accurate to the hit time
            hitClearTimer = 0.0f;
            if(playerPowerup)
            {
                [playerPowerup play];
            }
        }

        // Animate the pickup
        if (breathIn == NO)
        {
            // To breath out we increase the scale on x,y by an amount
            updateDataPtr4->scale.x += 0.0015f;
            updateDataPtr4->scale.y += 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = (updateDataPtr4->scale.x > origScale + 0.008f);
        }
        else if (breathIn == YES)
        {
            // To breath in we decrease the scale on x,y by an amount
            updateDataPtr4->scale.x -= 0.0015f;
            updateDataPtr4->scale.y -= 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = !(updateDataPtr4->scale.x < origScale - 0.008f);
        }
        
        // VERY IMPORTANT!! Now that the data was update you need to commit it for update
        // If you choose not to commit for whatever reason nothing changes. BUT THE DATA IS
        // NOT GUARENTEED PERSISTANT OVER UPDATES!!!
        // REMEMBER USE THE RIGHT OBJECT ID !!! for what you registered
        [glesRenderer updateCommit:REN_OBJ_PICKUP_4];
    }
}
// Pickup 5
- (void) onUpdateReqPickup5
{
    static bool breathIn = NO;
    static bool firstCall = YES;
    static float origScale = 0.0f;
    static float hitClearTimer = 0.0f;
    
    // VERY Important!!!! Get the updat dat at start of call back. This will be your working
    // ptr to buffered values. When you are finished you can commit the values so they update!
    REN_OBJ_DATA_MIN* updateDataPtr5 =[glesRenderer updateData:REN_OBJ_PICKUP_5];
    
    // Play it safe and always check that you have a valid pointer. It will be null if you
    // somehow submitted and invalid renderer object identifier.
    if (updateDataPtr5 != NULL)
    {
        if (firstCall == YES)
        {
            // On first call for this demo we gard the original scales to breath 'around'
            origScale = updateDataPtr5->scale.x;
            firstCall = NO;

            // If you want to show your object the first time then you need to set
            //  the position and visible flag to ON for showing and positioning it.
            // We want collision so we turn it on.
            updateDataPtr5->pos = GLKVector3Make(0.5f, -1.8f, 0.0f);
            updateDataPtr5->visible = YES;
            updateDataPtr5->collision.detectionOn = TRUE;
        }
        
        // Determine if object should be active / visible
        if (pickupsCollected != 4) {
            updateDataPtr5->visible = NO;
            updateDataPtr5->collision.detectionOn = FALSE;
        } else {
            updateDataPtr5->visible = YES;
            updateDataPtr5->collision.detectionOn = TRUE;
            glesRenderer.pickupPosX = updateDataPtr5->pos.x;
            glesRenderer.pickupPosY = updateDataPtr5->pos.y;
        }
        
        // Was a collision detected?
        if (updateDataPtr5->collision.isHit)
        {
            // Collision was detected so hide the object and clear hit
            updateDataPtr5->visible = NO;
            updateDataPtr5->collision.isHit = NO;
            pickupsCollected = 5;
            allPickupsCollected = TRUE;
            NSLog(@"Pickups Collected: %.1d", pickupsCollected);
            // want to make sure timer is accurate to the hit time
            hitClearTimer = 0.0f;
            if(playerPowerup)
            {
                [playerPowerup play];
            }
        }

        // Animate the pickup
        if (breathIn == NO)
        {
            // To breath out we increase the scale on x,y by an amount
            updateDataPtr5->scale.x += 0.0015f;
            updateDataPtr5->scale.y += 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = (updateDataPtr5->scale.x > origScale + 0.008f);
        }
        else if (breathIn == YES)
        {
            // To breath in we decrease the scale on x,y by an amount
            updateDataPtr5->scale.x -= 0.0015f;
            updateDataPtr5->scale.y -= 0.0015f;

            // It has passed the threshold than we need to breath in opposite direction
            breathIn = !(updateDataPtr5->scale.x < origScale - 0.008f);
        }
        
        // VERY IMPORTANT!! Now that the data was update you need to commit it for update
        // If you choose not to commit for whatever reason nothing changes. BUT THE DATA IS
        // NOT GUARENTEED PERSISTANT OVER UPDATES!!!
        // REMEMBER USE THE RIGHT OBJECT ID !!! for what you registered
        [glesRenderer updateCommit:REN_OBJ_PICKUP_5];
    }
}

// --------------------------------------------------------------------------
// Traps on the field.
- (void) onUpdateReqTrap1
{
    static bool firstCall = YES;
    static float hitClearTimer = 0.0f;
    static float hitClearToggle = 500.0f;
    const float hitClearPause = 2000.0f; // milliseconds
    const float hitDefaultToggle = 500.0f; // milliseconds

    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_TRAP_1];
    if (updateDataPtr != NULL)
    {
        if (firstCall == YES)
        {
            firstCall = NO;
            updateDataPtr->pos = GLKVector3Make(-1.0f, -0.5f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
        }
        
        //  if inTrapWait is active, ignore colloision detaction and wait for the timer to expire
        if (inTrapWait && inTrapOwner == REN_OBJ_TRAP_1)
        {
            // no hit so update the hit clear timer and check if it expired
            hitClearTimer += updateDataPtr->elapsedTime;
            if (hitClearTimer > hitClearPause)
            {
                // Timer is now expired, so clear the inTrapWait to signify the player to proceed
                // and start to look at the collision again
                inTrapWait = NO;
                updateDataPtr->collision.hitWith = REN_OBJ_NULL;
                updateDataPtr->collision.isHit = NO;
                
                // Collision was detected so hide the object and clear hit
                updateDataPtr->visible = NO;
                hitClearToggle = hitDefaultToggle;
            }
            // Every 0.5 second
            else if (hitClearTimer > hitClearToggle)
            {
                hitClearToggle += hitDefaultToggle;
                updateDataPtr->visible = !updateDataPtr->visible;
            }
        }// Was a collision detected?
        else if (updateDataPtr->collision.isHit)
        {
            // hit has occured, so set the trap timer period
            hitClearTimer = 0.0f;
            
            // Now set a new state and wait for timer to expire
            inTrapWait = YES;
            inTrapOwner = REN_OBJ_TRAP_1;
            if(playerVineGrowth)
            {
                [playerVineGrowth play];
            }
        }

        [glesRenderer updateCommit:REN_OBJ_TRAP_1];
    }
}

// Trap 2
- (void) onUpdateReqTrap2
{
    static bool firstCall = YES;
    static float hitClearTimer = 0.0f;
    static float hitClearToggle = 500.0f;
    const float hitClearPause = 2000.0f; // milliseconds
    const float hitDefaultToggle = 500.0f; // milliseconds

    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_TRAP_2];
    if (updateDataPtr != NULL)
    {
        if (firstCall == YES)
        {
            firstCall = NO;
            updateDataPtr->pos = GLKVector3Make(-0.50f, -1.15f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
        }
        
        //  if inTrapWait is active, ignore colloision detaction and wait for the timer to expire
        if (inTrapWait && inTrapOwner == REN_OBJ_TRAP_2)
        {
            // no hit so update the hit clear timer and check if it expired
            hitClearTimer += updateDataPtr->elapsedTime;
            if (hitClearTimer > hitClearPause)
            {
                // Timer is now expired, so clear the inTrapWait to signify the player to proceed
                // and start to look at the collision again
                inTrapWait = NO;
                updateDataPtr->collision.hitWith = REN_OBJ_NULL;
                updateDataPtr->collision.isHit = NO;
                
                // Collision was detected so hide the object and clear hit
                updateDataPtr->visible = NO;
                hitClearToggle = hitDefaultToggle;
            }
            // Every 0.5 second
            else if (hitClearTimer > hitClearToggle)
            {
                hitClearToggle += hitDefaultToggle;
                updateDataPtr->visible = !updateDataPtr->visible;
            }
        }// Was a collision detected?
        else if (updateDataPtr->collision.isHit)
        {
            // hit has occured, so set the trap timer period
            hitClearTimer = 0.0f;
            
            // Now set a new state and wait for timer to expire
            inTrapWait = YES;
            inTrapOwner = REN_OBJ_TRAP_2;
            if(playerVineGrowth)
            {
                [playerVineGrowth play];
            }
        }

        [glesRenderer updateCommit:REN_OBJ_TRAP_2];
    }
}
// Trap 3
- (void) onUpdateReqTrap3
{
    static bool firstCall = YES;
    static float hitClearTimer = 0.0f;
    static float hitClearToggle = 500.0f;
    const float hitClearPause = 2000.0f; // milliseconds
    const float hitDefaultToggle = 500.0f; // milliseconds

    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_TRAP_3];
    if (updateDataPtr != NULL)
    {
        if (firstCall == YES)
        {
            firstCall = NO;
            updateDataPtr->pos = GLKVector3Make(1.20f, 1.5f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
        }
        
        //  if inTrapWait is active, ignore colloision detaction and wait for the timer to expire
        if (inTrapWait && inTrapOwner == REN_OBJ_TRAP_3)
        {
            // no hit so update the hit clear timer and check if it expired
            hitClearTimer += updateDataPtr->elapsedTime;
            if (hitClearTimer > hitClearPause)
            {
                // Timer is now expired, so clear the inTrapWait to signify the player to proceed
                // and start to look at the collision again
                inTrapWait = NO;
                updateDataPtr->collision.hitWith = REN_OBJ_NULL;
                updateDataPtr->collision.isHit = NO;
                
                // Collision was detected so hide the object and clear hit
                updateDataPtr->visible = NO;
                hitClearToggle = hitDefaultToggle;
            }
            // Every 0.5 second
            else if (hitClearTimer > hitClearToggle)
            {
                hitClearToggle += hitDefaultToggle;
                updateDataPtr->visible = !updateDataPtr->visible;
            }
        }// Was a collision detected?
        else if (updateDataPtr->collision.isHit)
        {
            // hit has occured, so set the trap timer period
            hitClearTimer = 0.0f;
            
            // Now set a new state and wait for timer to expire
            inTrapWait = YES;
            inTrapOwner = REN_OBJ_TRAP_3;
            if(playerVineGrowth)
            {
                [playerVineGrowth play];
            }
        }

        [glesRenderer updateCommit:REN_OBJ_TRAP_3];
    }
}
// Trap 4
- (void) onUpdateReqTrap4
{
    static bool firstCall = YES;
    static float hitClearTimer = 0.0f;
    static float hitClearToggle = 500.0f;
    const float hitClearPause = 2000.0f; // milliseconds
    const float hitDefaultToggle = 500.0f; // milliseconds

    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_TRAP_4];
    if (updateDataPtr != NULL)
    {
        if (firstCall == YES)
        {
            firstCall = NO;
            updateDataPtr->pos = GLKVector3Make(0.65f, 1.25f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
        }
        
        //  if inTrapWait is active, ignore colloision detaction and wait for the timer to expire
        if (inTrapWait && inTrapOwner == REN_OBJ_TRAP_4)
        {
            // no hit so update the hit clear timer and check if it expired
            hitClearTimer += updateDataPtr->elapsedTime;
            if (hitClearTimer > hitClearPause)
            {
                // Timer is now expired, so clear the inTrapWait to signify the player to proceed
                // and start to look at the collision again
                inTrapWait = NO;
                updateDataPtr->collision.hitWith = REN_OBJ_NULL;
                updateDataPtr->collision.isHit = NO;
                
                // Collision was detected so hide the object and clear hit
                updateDataPtr->visible = NO;
                hitClearToggle = hitDefaultToggle;
            }
            // Every 0.5 second
            else if (hitClearTimer > hitClearToggle)
            {
                hitClearToggle += hitDefaultToggle;
                updateDataPtr->visible = !updateDataPtr->visible;
            }
        }// Was a collision detected?
        else if (updateDataPtr->collision.isHit)
        {
            // hit has occured, so set the trap timer period
            hitClearTimer = 0.0f;
            
            // Now set a new state and wait for timer to expire
            inTrapWait = YES;
            inTrapOwner = REN_OBJ_TRAP_4;
            if(playerVineGrowth)
            {
                [playerVineGrowth play];
            }
        }

        [glesRenderer updateCommit:REN_OBJ_TRAP_4];
    }
}
// Trap 5
- (void) onUpdateReqTrap5
{
    static bool firstCall = YES;
    static float hitClearTimer = 0.0f;
    static float hitClearToggle = 500.0f;
    const float hitClearPause = 2000.0f; // milliseconds
    const float hitDefaultToggle = 500.0f; // milliseconds

    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_TRAP_5];
    if (updateDataPtr != NULL)
    {
        if (firstCall == YES)
        {
            firstCall = NO;
            updateDataPtr->pos = GLKVector3Make(0.55f, -1.15f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
        }
        
        //  if inTrapWait is active, ignore colloision detaction and wait for the timer to expire
        if (inTrapWait && inTrapOwner == REN_OBJ_TRAP_5)
        {
            // no hit so update the hit clear timer and check if it expired
            hitClearTimer += updateDataPtr->elapsedTime;
            if (hitClearTimer > hitClearPause)
            {
                // Timer is now expired, so clear the inTrapWait to signify the player to proceed
                // and start to look at the collision again
                inTrapWait = NO;
                updateDataPtr->collision.hitWith = REN_OBJ_NULL;
                updateDataPtr->collision.isHit = NO;
                
                // Collision was detected so hide the object and clear hit
                updateDataPtr->visible = NO;
                hitClearToggle = hitDefaultToggle;
            }
            // Every 0.5 second
            else if (hitClearTimer > hitClearToggle)
            {
                hitClearToggle += hitDefaultToggle;
                updateDataPtr->visible = !updateDataPtr->visible;
            }
        }// Was a collision detected?
        else if (updateDataPtr->collision.isHit)
        {
            // hit has occured, so set the trap timer period
            hitClearTimer = 0.0f;
            
            // Now set a new state and wait for timer to expire
            inTrapWait = YES;
            inTrapOwner = REN_OBJ_TRAP_5;
            if(playerVineGrowth)
            {
                [playerVineGrowth play];
            }
        }

        [glesRenderer updateCommit:REN_OBJ_TRAP_5];
    }
}

// --------------------------------------------------------------------------

// Obstacles on the field.
- (void) onUpdateReqObstacle1
{
    static bool firstCall = YES;
    if (firstCall == YES)
    {
        REN_OBJ_DATA_MIN* obsPtr1 =[glesRenderer updateData:REN_OBJ_OBSTACLE_1];
        if (obsPtr1 != NULL)
        {
            firstCall = NO;
            obsPtr1->pos = GLKVector3Make(-1.05f, 2.35f, 0.0f);
            obsPtr1->rot = GLKVector3Make(45.0, 0.0, 0.0);
            obsPtr1->visible = YES;
            [glesRenderer updateCommit:REN_OBJ_OBSTACLE_1];
        }
    }
}
    
// Obstacle 2
- (void) onUpdateReqObstacle2
{
    static bool firstCall = YES;
    if (firstCall == YES)
    {
        REN_OBJ_DATA_MIN* obsPtr2 =[glesRenderer updateData:REN_OBJ_OBSTACLE_2];
        if (obsPtr2 != NULL)
        {
            firstCall = NO;
            obsPtr2->pos = GLKVector3Make(-0.50f, 2.45f, 0.0f);
            obsPtr2->rot = GLKVector3Make(45.0, 0.0, 0.0);
            obsPtr2->visible = YES;
            [glesRenderer updateCommit:REN_OBJ_OBSTACLE_2];
        }
    }
}
    
// Obstacle 3
- (void) onUpdateReqObstacle3
{
    static bool firstCall = YES;
    if (firstCall == YES)
    {
        REN_OBJ_DATA_MIN* obsPtr3 =[glesRenderer updateData:REN_OBJ_OBSTACLE_3];
        if (obsPtr3 != NULL)
        {
            firstCall = NO;
            obsPtr3->pos = GLKVector3Make(-0.75f, 0.85f, 0.0f);
            obsPtr3->rot = GLKVector3Make(45.0, 0.0, 0.0);
            obsPtr3->visible = YES;
            [glesRenderer updateCommit:REN_OBJ_OBSTACLE_3];
        }
    }
}
    
// Obstacle 4
- (void) onUpdateReqObstacle4
{
    static bool firstCall = YES;
    if (firstCall == YES)
    {
        REN_OBJ_DATA_MIN* obsPtr4 =[glesRenderer updateData:REN_OBJ_OBSTACLE_4];
        if (obsPtr4 != NULL)
        {
            firstCall = NO;
            obsPtr4->pos = GLKVector3Make(0.85f, 0.45f, 0.0f);
            obsPtr4->rot = GLKVector3Make(45.0, 0.0, 0.0);
            obsPtr4->visible = YES;
            [glesRenderer updateCommit:REN_OBJ_OBSTACLE_4];
        }
    }
}
    
// Obstacle 5
- (void) onUpdateReqObstacle5
{
    static bool firstCall = YES;
    if (firstCall == YES)
    {
        REN_OBJ_DATA_MIN* obsPtr5 =[glesRenderer updateData:REN_OBJ_OBSTACLE_5];
        if (obsPtr5 != NULL)
        {
            firstCall = NO;
            obsPtr5->pos = GLKVector3Make(-0.95f, -1.15f, 0.0f);
            obsPtr5->rot = GLKVector3Make(45.0, 0.0, 0.0);
            obsPtr5->visible = YES;
            [glesRenderer updateCommit:REN_OBJ_OBSTACLE_5];
        }
    }
}

// --------------------------------------------------------------------------

// Floor
- (void) onUpdateReqFloor
{
    REN_OBJ_DATA_MIN* floorPtr =[glesRenderer updateData:REN_OBJ_GROUND_PLANE];
    if (floorPtr != NULL)
    {
        floorPtr->pos = GLKVector3Make(0.0f, 0.0f, -1.0f);
        floorPtr->visible = YES;
        [glesRenderer updateCommit:REN_OBJ_GROUND_PLANE];
    }
}

// --------------------------------------------------------------------------

- (void) onUpdateReq_Player
{
    static float runSpeed = 0.02f;
    static float sprintSpeed = 0.04f;

    static float hitClearTimer = 0.0f;
    const float hitClearPause = 1500; // milliseconds
    
    const float maxX = 1.5f;
    const float minX = -1.5f;
    const float maxY = 2.7f;
    const float minY = -2.7f;

    static REN_OBJ inHitWith;
    static REN_TAG_ID inHitWithTag;


    REN_OBJ_DATA_MIN* updateDataPtr =[glesRenderer updateData:REN_OBJ_PLAYER];
    if (updateDataPtr != NULL)
    {
        updateDataPtr->rot = GLKVector3Make(45.0, 0.0, 0.0);
        if (firstCallPlayer == YES)
        {
            // On first call for this demo we gard the original scales to breath 'around'
            firstCallPlayer = NO;
            // We want collision so we turn it on.
            updateDataPtr->pos = GLKVector3Make(0.0f, 0.0f, 0.0f);
            updateDataPtr->visible = YES;
            updateDataPtr->collision.detectionOn = TRUE;
            inHitWith = REN_OBJ_NULL;
            inHitWithTag = REN_TAG_NONE;
            updateDataPtr->collision.isHit = NO;
            hitClearTimer = 0.0f;
        }

        // Based on Tag check if collsion occured and handle it
        if (inHitWith == REN_OBJ_NULL && updateDataPtr->collision.isHit == YES)
        {
            inHitWith = updateDataPtr->collision.hitWith;
            inHitWithTag = updateDataPtr->collision.tagID;
        }
        
        if (inHitWith != REN_OBJ_NULL)
        {
            switch (inHitWithTag)
            {
                case REN_TAG_OBSTACLE:
                    // Do your processing for the hit but when hit is done then reset inHitWith & inHitWithTarget
                    updateDataPtr->collision.isHit = NO;
                    inHitWith = REN_OBJ_NULL;
                    inHitWithTag = REN_TAG_NONE;
                    break;

                case REN_TAG_TRAP:
                    // Was a collision detected?
                    if (updateDataPtr->collision.isHit)
                    {
                        // Change color to red
                        updateDataPtr->rgb = GLKVector3Make(1.0f, 0.0f, 0.0f);
                        updateDataPtr->collision.isHit = NO;
                        
                        // want to make sure timer is accurate to the hit time
                        hitClearTimer = 0.0f;
                    }
                    else
                    {
                        // no hit so update the hit clear timer and check if it expired
                        float oneCycle =updateDataPtr->elapsedTime;
                        hitClearTimer += oneCycle;
                        if (hitClearTimer > hitClearPause)
                        {
                            // Change color yellow when no hit
                            updateDataPtr->rgb = GLKVector3Make(1.0f, 1.0f, 0.0f);
                            inHitWith = REN_OBJ_NULL;
                            inHitWithTag = REN_TAG_NONE;
                        }
                    }
                    break;

                default:
                    break;
            }
        }
        
        float newX, newY;
        // record the new position of player
        if (currentLevel != 3)
        {
            if (isSprinting)
            {
                newX = updateDataPtr->pos.x + panMoveX * 0.9 * sprintSpeed;
                newY = updateDataPtr->pos.y + -panMoveY * 1.1 * sprintSpeed;
            }
            else
            {
                newX = updateDataPtr->pos.x + panMoveX * 0.9 * runSpeed;
                newY = updateDataPtr->pos.y + -panMoveY * 1.1 * runSpeed;
            }
        }
        else
        {
            if (fabsf(netForce.x) + fabsf(netForce.y) > 2)
            {
                netForce = GLKVector2Normalize(netForce);
            }
            newX = updateDataPtr->pos.x + netForce.x * sprintSpeed;
            newY = updateDataPtr->pos.y + netForce.y * sprintSpeed;
        }
        
        // Check if the new player position would collide with obstacle or border
        hitObstacle = [glesRenderer checkCollidePos:newX andPosY:newY];
        
        hitBorder = !(newX >= minX && newX <= maxX && newY >= minY && newY <= maxY);
        
        // Allow player movement only if free from trap and would not collide with obstacle or border
        if (inTrapWait == NO && timerSecond > -1 && !allPickupsCollected && !hitObstacle && !hitBorder)
        {
            if (playerStepInGrass && (updateDataPtr->pos.x != newX || updateDataPtr->pos.y != newY))
            {
                [playerStepInGrass play];
            }
            updateDataPtr->pos.x = newX;
            updateDataPtr->pos.y = newY;
        }
        
        glesRenderer.playerPosX = updateDataPtr->pos.x;
        glesRenderer.playerPosY = updateDataPtr->pos.y;
        
        // VERY IMPORTANT!! Now that the data was update you need to commit it for update
        // If you choose not to commit for whatever reason nothing changes. BUT THE DATA IS
        // NOT GUARENTEED PERSISTANT OVER UPDATES!!!
        // REMEMBER USE THE RIGHT OBJECT ID !!! for what you registered
        [glesRenderer updateCommit:REN_OBJ_PLAYER];
    }
}

#pragma mark - Button triggers

//===========================================================================
// The continue button callback activated when the UI button is pressed
//===========================================================================
- (IBAction)ContinueToScoreBtn:(id)sender {
    
    if (playerFluteWin && !showingStats)
    {
        [playerFluteWin play];
    }
    HighScoreTitle.hidden = showingStats;
    ScoresStackView.hidden = showingStats;
    showingStats = !showingStats;
}


//===========================================================================
// The Play button callback activated when the UI button is pressed
//===========================================================================
- (IBAction)btnPlay:(id)sender {
//        NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]
//                                                 pathForResource:@"bleep"
//                                                 ofType:@"mp3"]];
      
        //[player play];
}


//===========================================================================
// The next level button callback activated when the UI button is pressed
//===========================================================================
- (IBAction)NextLevelBtn:(id)sender {
    
    // Make sure stats aren't showing
    if (showingStats == YES)
    {
        HighScoreTitle.hidden = YES;
        ScoresStackView.hidden = YES;
        showingStats = NO;
    }
    
    if (allPickupsCollected)
    {
        currentLevel++;
    }
    
    if (currentLevel > 3) currentLevel = 1;
    
    [self loadLevel:currentLevel];
}


#pragma mark - Helpers

-(void)loadLevel: (int) level;
{
    // resest game state variables
    allPickupsCollected = false;
    timerSecond = MAX_TIMER;
    timerMillisecond = 0;
    pickupsCollected = 0;
    playOnce = YES;
    [self resetPlayer];
    [self resetTraps];
    checkHighScore = YES;
    [HighScoreLabel setText:[NSString stringWithFormat:@"Time To Beat: %.1f", hsMgr.LowestHighScore]];

    
    switch (level) {
        case 1:
            glesRenderer.specularComponent = GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f);
            glesRenderer.ambientComponent = GLKVector4Make(0.65f, 0.65f, 0.65f, 1.0f);
            [glesRenderer changeFloorTexture:false];
            break;
            
        case 2:
            glesRenderer.specularComponent = GLKVector4Make(1.0f, 1.0f, 1.0f, 1.0f);
            glesRenderer.ambientComponent = GLKVector4Make(0.35f, 0.35f, 0.35f, 1.0f);
            break;
            
        case 3:
            glesRenderer.specularComponent = GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f);
            glesRenderer.ambientComponent = GLKVector4Make(0.65f, 0.65f, 0.65f, 1.0f);
            [glesRenderer changeFloorTexture:true];
            break;
            
        default:
            break;
    }
}

-(void)resetPlayer
{
    firstCallPlayer = true;
}

-(void)resetTraps
{
    REN_OBJ_DATA_MIN* trap1Ptr =[glesRenderer updateData:REN_OBJ_TRAP_1];
    if (trap1Ptr != NULL)
    {
        trap1Ptr->visible = YES;
        trap1Ptr->collision.detectionOn = TRUE;
        [glesRenderer updateCommit:REN_OBJ_TRAP_1];
    }
    
    REN_OBJ_DATA_MIN* trap2Ptr =[glesRenderer updateData:REN_OBJ_TRAP_2];
    if (trap2Ptr != NULL)
    {
        trap2Ptr->visible = YES;
        trap2Ptr->collision.detectionOn = TRUE;
        [glesRenderer updateCommit:REN_OBJ_TRAP_2];
    }
    
    REN_OBJ_DATA_MIN* trap3Ptr =[glesRenderer updateData:REN_OBJ_TRAP_3];
    if (trap3Ptr != NULL)
    {
        trap3Ptr->visible = YES;
        trap3Ptr->collision.detectionOn = TRUE;
        [glesRenderer updateCommit:REN_OBJ_TRAP_3];
    }
    
    REN_OBJ_DATA_MIN* trap4Ptr =[glesRenderer updateData:REN_OBJ_TRAP_4];
    if (trap4Ptr != NULL)
    {
        trap4Ptr->visible = YES;
        trap4Ptr->collision.detectionOn = TRUE;
        [glesRenderer updateCommit:REN_OBJ_TRAP_4];
    }
    
    REN_OBJ_DATA_MIN* trap5Ptr =[glesRenderer updateData:REN_OBJ_TRAP_5];
    if (trap5Ptr != NULL)
    {
        trap5Ptr->visible = YES;
        trap5Ptr->collision.detectionOn = TRUE;
        [glesRenderer updateCommit:REN_OBJ_TRAP_5];
    }
}

// timer function
-(void)timerFired
{
    if ((timerSecond > 0 || timerMillisecond >= 0) && !allPickupsCollected)
    {
        if (timerMillisecond == 0)
        {
            timerSecond --;
            timerMillisecond = 9;
        }
        else if (timerMillisecond > 0)
        {
            timerMillisecond--;
        }
        
        if (timerSecond > -1)
        {
            // Setting the text to the correct time recorded for the timer label 
            [timerLabel setText:[NSString stringWithFormat:@"%d.%d", timerSecond, timerMillisecond]];
        }
    }
    else if (allPickupsCollected)
    {
        // Game over
        if ( checkHighScore && [hsMgr NewCurrentScore:timerSecond :timerMillisecond])
        {
            // A new hight score was recorded
            [self UpdateHighScoreScreen];
            [hsMgr SaveHighScores];
        }
        checkHighScore = NO;
    }
}

// helper function to mimic force application on player
-(void)applyMovementForce
{
    GLKVector2 newForce = GLKVector2Make(panMoveX, -panMoveY);
    netForce = GLKVector2Add(netForce, newForce);
}

// helper function to mimic frictional force application on player
-(void)applyFrictionForce
{
    GLKVector2 frictionForce = GLKVector2Make(-netForce.x/3, -netForce.y/3);
    netForce = GLKVector2Add(netForce, frictionForce);
}

@end
