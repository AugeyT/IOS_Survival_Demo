//
//  HighScoreManager.m
//  Survival
//
//  Created by socas on 2021-04-01.
//

#import "HighScoreManager.h"


@implementation HSEntry

@synthesize date;
@synthesize score;

@end

// There are 5 high score entries so append the integer to end of string!!!!
#define HIGHSCRORE_DATES_KEY_FORMATTER @"SurvivalhighDates%d"
#define HIGHSCRORE_SCORES_KEY_FORMATTER @"SurvivalhighScores%d"

//===========================================================================
//  Class interface
//
@interface HighScoreManager () {
    HighScoreManager *highScoreM;
    
    NSMutableArray *hsList;
    float currScore;
    bool hsRequiresSave;
    bool isScoresLoaded;
    float maxCurrScore;
    NSUserDefaults *ourDefaults;
}

@end


//===========================================================================
//  Class implementation
//
@implementation HighScoreManager : NSObject

//===========================================================================
// Private method the inserts the current score in to our array of high
//  scores. This will find an insertion point and push everything down one
//  location in list to make room for th eew high score. lowest score is
//  knocked out of the list. Note: methods job to save to user defaults
//===========================================================================
- (bool) insertHS
{
    bool rslt = NO;
    
    // TODO build the logic but for now always return false to test
    
    // Loop through lowest to highest
    for (int i = 0; i < hsList.count && rslt == NO; i++)
    {
        HSEntry *obj = hsList[i];
        
        // compare if the currScore beats a value
        if (obj.score < currScore)
        {
            // score location found so need to moving everything in list at this location one down
            
            int j = (int)hsList.count - 1;
            while (j > i)
            {
                // If j's previous is not above i we replace
                if ((j - 1) >= i)
                {
                    [hsList exchangeObjectAtIndex:j - 1 withObjectAtIndex:j];
                }
                // Move j up the list and reevaluate
                j--;
            }
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"MMM dd, yyyy HH:mm"];
            NSDate *currentDate = [NSDate date];
            NSString *dateString = [formatter stringFromDate:currentDate];
            
            HSEntry *newEntry = [HSEntry alloc];
            newEntry.date = dateString;
            newEntry.score = currScore;
            
            [hsList setObject:newEntry atIndexedSubscript:i];
            rslt = YES;
        }
    }
    
    // Never want to wipe out the fact a previous save could have needed a save
    if (hsRequiresSave == NO) {
        hsRequiresSave = rslt;
    }
    
    return rslt;
}


//===========================================================================
// Setup must be called FIRST before ANY METHOD used as we are not
//  overriding the initailzer
//===========================================================================
- (void)Setup:(float) maxCurrentScore
{
    hsList = [NSMutableArray new];
    maxCurrScore = maxCurrentScore;
    currScore = maxCurrScore;
    hsRequiresSave = NO;
    isScoresLoaded = NO;
    ourDefaults = [NSUserDefaults standardUserDefaults];
}


//===========================================================================
// method will load the high scores from th euser defaults. If it finds
//  that we had never created the default it will make sure an entry is
//  setup with the appropriate defaults.
//===========================================================================
- (bool) LoadHighScores
{
    // We will loop through each entry and save each element as a unique key
    //  DO NOT CHANGE THE ORDER OF LOAD must start with zero key for first
    //  array entry and so forth, not doing it means list is in wrong order
    [hsList removeAllObjects];
    for (int i = 0; i < 5; i++)
    {
        // Create a new entry to populate and store
        HSEntry *entry = [HSEntry alloc];

        // Create our keys for the pair of entry data, date of high score and actual score
        NSString *keyDate = [NSString stringWithFormat:HIGHSCRORE_DATES_KEY_FORMATTER, i+1];
        NSString *keyScore = [NSString stringWithFormat:HIGHSCRORE_SCORES_KEY_FORMATTER, i+1];
        
        // Populate the entry with values stored in the local user defaults
        entry.date = [ourDefaults stringForKey:keyDate];
        entry.score = [ourDefaults floatForKey:keyScore];

        // Was there any default ever created or first time after app installed?
        if (entry.date == NULL)
        {
            // Yes, so put a marker that this entry has no high score
            entry.date = @"--";
        }
        
        // Add the entry to our object list
        [hsList addObject:entry];
    }
    
    return YES;
}


//===========================================================================
// Saves all the high scores in our class to the local user defaults
//===========================================================================
- (bool) SaveHighScores
{
    // loop through the total array items saving them to user defaults
    for (int i = 0; i < hsList.count; i++)
    {
        // Create pointer to the entry we are going to save its data
        HSEntry *entry = hsList[i];

        // Create our key strings for the date and score.
        // NOTE the key is a base string we do not change but we append the index to complete the key
        NSString *keyDate = [NSString stringWithFormat:HIGHSCRORE_DATES_KEY_FORMATTER, i+1];
        NSString *keyScore = [NSString stringWithFormat:HIGHSCRORE_SCORES_KEY_FORMATTER, i+1];

        // store each item of the entry to its key in user defaults
        [ourDefaults setObject:entry.date forKey:keyDate];
        [ourDefaults setFloat:entry.score forKey:keyScore];
    }
    
    // Lastly push the system buffered data to local app storge area.
    //  Note that iOS does do this periodically bit at large intervals
    //  we are enforcing the push should the gae run in too issues.
    [ourDefaults synchronize];

    return YES;
}


//===========================================================================
// Records the current score as two components: seconds and miliseconds
// NOTE: DO NOT call this method every frame only when a level is over
//       and only once or it is possible to add a current score twice.
//===========================================================================
- (bool) NewCurrentScore:(NSInteger) seconds : (NSInteger) ms
{
    // Convert the two arguements into a float
    currScore = seconds + ((float)ms / 10.0);
    
    // With new score we do an immediate evaluation to see if it goes in list
    return [self insertHS];
}


//===========================================================================
// Records the current score as float
// NOTE: DO NOT call this method every frame only when a level is over
//       and only once or it is possible to add a current score twice.
//===========================================================================
- (bool) NewCurrentScore:(float) time
{
    // record the current score in our class
    currScore = time;
    
    // With new score we do an immediate evaluation to see if it goes in list
    return [self insertHS];
}


//===========================================================================
// Retieves the lowest high score (last list object) to report what
//  is the minimum time required to achieve a high score.
//===========================================================================
- (float) LowestHighScore
{
    // Get the last object in our list
    HSEntry *obj = hsList.lastObject;
    
    // return the last objects score
    return obj.score;
}


//===========================================================================
// Will report if the high score list would need a save due to a change
//===========================================================================
- (bool) RequiresSave
{
    return hsRequiresSave;
}


//===========================================================================
// Will return our mutable array as a copy. This can nake cleaner code and
//  reduce the number of calls to populate a clients UI.
//===========================================================================
- (NSArray*) GetHighScoreList
{
    return hsList;
}

@end
