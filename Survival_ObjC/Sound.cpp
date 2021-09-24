////
////  Sound.cpp
////  Survival
////
////  Created by socas on 2021-03-12.
////
//
//#include "Sound.h"
//
//#include <iostream>
//// sound lib
////#include "bass.h"
//
//bool Sound::audio_device = false;
//
//Sound::Sound(const char * filename)
//{
//    // init
//    if(!audio_device)
//    {
//        if(!BASS_Init(-1, 44100, 0, NULL,NULL))
//        {
//            printf("erorr loading sound file \n");
//        }
//        audio_device = true;
//    }
//
//    channel = BASS_StreamCreateFile(false,filename, 0,0, BASS_SAMPLE_LOOP);
//
//    if(!channel)
//    {
//        printf("can't play file \n");
//    }
//}
//
//Sound::~Sound()
//{
//    BASS_Free();
//}
//
//void Sound::play()
//{
//    BASS_ChannelPlay(channel, false);
//}
//
//void Sound::pause()
//{
//    BASS_ChannelPause(channel);
//}
//
//void Sound::stop()
//{
//    BASS_ChannelStop(channel);
//}






//#include <iostream>
//#include <irrKlang.h>
//using namespace irrklang;
//
//int main(int argc, const char** argv)
//{
//  // start the sound engine with default parameters
//  ISoundEngine* engine = createIrrKlangDevice();
//
//  if (!engine)
//    return 0; // error starting up the engine
//
//  // play some sound stream, looped
//  engine->play2D("somefile.mp3", true);
//
//  char i = 0;
//  std::cin >> i; // wait for user to press some key
//
//  engine->drop(); // delete engine
//  return 0;
//}
