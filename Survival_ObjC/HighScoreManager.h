//
//  HighScoreManager.h
//  Survival
//
//  Created by socas on 2021-04-01.
//

#ifndef High_h
#define Renderer_h
#import <GLKit/GLKit.h>

@interface HSEntry : NSObject

    @property NSString *date;
    @property float score;

@end


@interface HighScoreManager : NSObject

// Must be called before calling any other methods
- (void)Setup:(float) maxCurrentScore;

- (bool) LoadHighScores;
- (bool) SaveHighScores;
- (bool) NewCurrentScore:(NSInteger) seconds : (NSInteger) ms;
- (bool) NewCurrentScore:(float) time;
- (float) LowestHighScore;
- (bool) RequiresSave;
- (NSArray*) GetHighScoreList;

@end

#endif /* Renderer_h */
