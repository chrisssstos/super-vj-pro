import themidibus.*;
import oscP5.*;
import netP5.*;
import spout.*;
import processing.sound.*;
import java.util.HashMap;

boolean entered7=true;
MidiBus midi;
OscP5 oscP5;
NetAddress resolume;
Spout spoutReceiver;
//trouboleshooting
long lastMessageTime = 0;
long lastMidiSendTime = 0;
long messageInterval = 50;  // Minimum 50ms between messages
long midiSendInterval = 20; // Minimum 20ms between MIDI messages
//////
long lastMidiMessageTime = 0; // Timestamp of the last MIDI message
long midiMessageCooldown = 40; // Minimum time (in ms) between MIDI messages to avoid cheating
int midiMessageCounter = 0; // Counter for MIDI messages within a short timespan
long midiMessageWindowStart = 0; // Start time of the current message window
int midiMessageThreshold = 2; // Maximum allowed messages within the window
long midiMessageWindowDuration = 100; // Duration (in ms) of the message window
boolean midiCooldownActive = false; // Tracks if the system is in cooldown mode
long midiCooldownEndTime = 0; // Timestamp when the cooldown period ends
long midiCooldownDuration = 1000; // Duration (in ms) of the cooldown period
/////

int totalButtonPresses = 0;
int onBeatPresses = 0;
int totalSliderMovements = 0;
int buttonMashCount = 0; // Tracks rapid button presses
long lastButtonPressTime = 0; // Tracks the time of the last button press
long buttonMashWindow = 600; // Time window (in ms) to consider rapid presses as mashing

// SoundFiles for Levels 1–4
SoundFile level1Music;
SoundFile level2Music;
SoundFile level3Music;
SoundFile level4Music;
SoundFile level5Music;
SoundFile level6Music;
SoundFile level7Music;
SoundFile failwav;
BeatDetector beatDetector;
boolean isPressedBeat  = false;
boolean isPressedBeatNICE  = false;
boolean offsync=false;

boolean level4triggervisual=true;
// Add these variables at the top of your code
int failDisplayStartTime = -1; // Tracks when the FAIL text was displayed
int niceDisplayStartTime = -1; // Tracks when the NICE text was displayed
int niceDisplayDuration = 400; // Duration in milliseconds
int failDisplayDuration = 400; // Duration in milliseconds (2 seconds)
int level5score=0;

boolean slider24AtMin = false; // Tracks if the slider is at the minimum value (0)
boolean slider24AtMax = false; // Tracks if the slider is at the maximum value (127)
String fail;

int beatWindow = 150; // Time window in milliseconds (before and after the beat)
int lastBeatTime = -beatWindow; // Initialize to ensure no false trigger at start
PImage ndiFrame;

// MIDI-to-OSC Mapping
HashMap<Integer, String> midiToOscMapping = new HashMap<>();
float[] loopValues = new float[8]; // For encoders

int[] allowedLoops = {4, 3, 4, 4, 4, 4, 4}; // Number of loops allowed for each level (adjust as needed)
int loopsSinceLevelStart = 0; // Tracks the number of loops since the level started


// Current level
int currentLevel   = 1;

//------------------------------------------
// Level 1: Single button logic
//------------------------------------------
int triggerCount   = 0;
boolean isTriggered= false;
boolean isPressed  = false;
int activeButton1  = 52;

//------------------------------------------
// Level 2: Row logic
//------------------------------------------
int level2TriggerCount = 0;
int required2Triggers  = 4;
int level5TriggerCount = 0;
int required5Triggers  = 8;
int[] row2 = {52, 53, 54, 55, 84, 85, 86, 87};

//------------------------------------------
// Level 3: (No beat detection now)
//------------------------------------------
int onBeatCount = 0;
int required3Triggers  = 3;

//------------------------------------------
// Level 4: Row logic + slider #24
//------------------------------------------

//------------------------------------------
// Level 5: Row logic
//------------------------------------------
//int level2TriggerCount = 0;
//int required2Triggers  = 4;
int[] row5top = {56, 57, 58, 59, 88, 89, 90, 91};
int[] row5 = {52, 53, 54, 55, 84, 85, 86, 87,
  56, 57, 58, 59, 88, 89, 90, 91};
// For slider #24 cycling
int slider24CycleCount   = 0;
float lastSlider24Value  = 0;
boolean slider24Increasing = false;
int lvl5score=0;



// For Level 6: Slider 20-23 cycle tracking
boolean[] sliderAtMin = {false, false, false, false}; // Tracks if sliders 20-23 are at the minimum value (0)
boolean[] sliderAtMax = {false, false, false, false}; // Tracks if sliders 20-23 are at the maximum value (127)
int[] sliderCycleCount = {0, 0, 0, 0}; // Tracks how many times each slider has been cycled
int requiredSliderCycles = 3; // Number of cycles required to progress to Level 7
//------------------------------------------
// Loop boundary approach for level transitions
//------------------------------------------
int loopCount       = 0;
float lastPos       = 0;
int pendingLevel    = -1;
int targetLoopCount = -1;

// END
int finalLevelLoops = 3; // Number of loops for the final level (adjustable)
boolean showEndScreen = false; // Tracks if the end screen should be displayed


// For complete 8x8 grid
int[] grid = {
  52, 53, 54, 55, 84, 85, 86, 87,
  56, 57, 58, 59, 88, 89, 90, 91,
  60, 61, 62, 63, 92, 93, 94, 95,
  64, 65, 66, 67, 96, 97, 98, 99
};

PFont bold;

void setup() {

  size(960, 540, P3D);
  background(0);
  textSize(20);
  fill(255);
  bold=createFont("futur.ttf", 120/2);

  // Create a BeatDetector and set its input
  beatDetector = new BeatDetector(this);
  beatDetector.input(null);
  fail = "FAIL"; // The text you want to display


  // Set the sensitivity of the beat detector (optional)
  beatDetector.sensitivity(2); // Adjust sensitivity in milliseconds
  // MIDI Setup
  MidiBus.list();
  midi = new MidiBus(this, "Pico 2", "Pico 2");

  // OSC Setup
  oscP5 = new OscP5(this, 7001);
  resolume = new NetAddress("127.0.0.1", 7000);

  // Spout Setup
  spoutReceiver = new Spout(this);
  spoutReceiver.createReceiver("Arena");
  ndiFrame = createImage(width, height, RGB);

  // Load SoundFiles
  level1Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 1.wav");
  level2Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 2.wav");
  level3Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 3.wav");
  level4Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 4.wav");
  level5Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 5.wav");
  level6Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 6.wav");
  level7Music = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\Bitchboys song 7.wav");
  failwav = new SoundFile(this, "C:\\Users\\hrist\\Pictures\\bitchboy\\Assets\\fail.wav");
  // Start Level 1 track in loop
  level1Music.loop();

  // Build MIDI->OSC map
  int[] midiNotes = {
    52, 53, 54, 55, 84, 85, 86, 87,
    56, 57, 58, 59, 88, 89, 90, 91,
    60, 61, 62, 63, 92, 93, 94, 95,
    64, 65, 66, 67, 96, 97, 98, 99
  };
  for (int i = 0; i < midiNotes.length; i++) {
    int layer = (i / 8) + 1;
    int clip  = (i % 8) + 1;
    midiToOscMapping.put(midiNotes[i],
      "/composition/layers/" + layer + "/clips/" + clip + "/connect");
  }
  // Initially turn off all grid LEDs
  for (int i = 0; i < grid.length; i++) {
    sendMidiFeedback(grid[i], 1

      );
  }
  OscMessage disconnect = new OscMessage("/composition/disconnectall");

  oscP5.send(disconnect, resolume);
  disconnect.add(0);
  oscP5.send(disconnect, resolume);
}

void draw() {
  if (showEndScreen) {
    displayEndScreen();
    return; // Stop further drawing
  }
  background(0);

  checkTrackLoop();
  lightUpButtons(); // Lights up relevant buttons per level

  // If spout feed present
  if (spoutReceiver.isConnected()) {
    ndiFrame = spoutReceiver.receiveImage(ndiFrame);
    image(ndiFrame, 0, 0, width, height);
  } else {
    text(" ", 50, 180);
  }

  // Display level-specific text only when needed
  displayLevelText();

  // Display big feedback for success or failure
  displayFeedback();
  // Display score from Level 3 onwards
  if (currentLevel >= 3) {
    textSize(24);
    fill(255);
    textAlign(LEFT, TOP);
    text("Score: " + onBeatCount, 50, 50);
  }

  // Check for bonus level unlock condition during freestyle level
  //if (currentLevel == 7) {
  //  boolean allSlidersAtZero = true;
  //  for (int i = 20; i <= 23; i++) {
  //    if (sliderAtMax[i - 20] || sliderAtMin[i - 20]) {
  //      allSlidersAtZero = false;
  //      break;
  //    }
  //  }
  //  if (allSlidersAtZero) {
  //    bonusLevelUnlocked = true;
  //    println("Bonus level unlocked!");
  //  }
  //}

  // Handle bonus level logic
  //if (bonusLevelUnlocked) {
  //  textSize(40);
  //  fill(0, 255, 0);
  //  textAlign(CENTER, CENTER);
  //  text("BONUS LEVEL: ENCODERS x2 POINTS!", width / 2, height / 1.5);
  //}



  beatDetection();
}


// ---------------------------------------------------------------------------
// Display level-specific text
// ---------------------------------------------------------------------------
void displayLevelText() {
  textFont(bold);
  fill(255); // White color
  textAlign(CENTER, CENTER); // Center the text

  if (currentLevel == 1) {
    if (triggerCount == 0) {
      text("ORANGE BUTTON", width / 2, height / 1.2);
    } else if (triggerCount == 1) {
      text("AGAIN", width / 2, height / 1.2);
    } else if (triggerCount == 2) {
      text("KEEP PRESSING", width / 2, height / 1.2);
    } else if (triggerCount == 3) {
      text("GOOD", width / 2, height / 1.2);
    } else if (triggerCount >= 6) {
      text("NICE BRO", width / 2, height / 1.2);
    }
  } else if (currentLevel == 2) {
    if (level2TriggerCount == 0) {
      text("MORE BUTTONS", width / 2, height / 1.2);
    } else if (level2TriggerCount == 2) {
      text("KEEP GOING", width / 2, height / 1.2);
    } else if (level2TriggerCount >= required2Triggers) {
      text("HELL YEA", width / 2, height / 1.2);
    }
  } else if (currentLevel == 3) {
    if (onBeatCount == 0) {
      text("PRESS ON BEAT", width / 2, height / 1.2);
    } else if (onBeatCount == 4) {
      text("KEEP SYNCING", width / 2, height / 1.2);
    } else if (onBeatCount >= required3Triggers+1) {
      text("DUUUDE", width / 2, height / 1.2);
    }
  } else if (currentLevel == 4) {
    if (level4triggervisual) {
      for (int i=2; i>0; i--) {
        OscMessage level4b = new OscMessage("/composition/layers/1/clips/"+i+"/connect");
        oscP5.send(level4b, resolume);
      }
      level4triggervisual=false;
      //level4b = new OscMessage("/composition/layers/1/clips/1/connect");
      //oscP5.send(level4b, resolume);
      //sendOscMessageWithValue("/composition/layers/1/clips/1/connect", 1);
    }

    if (slider24CycleCount == 0) {
      text("MOVE SLIDER 1", width / 2, height / 1.2);
    } else if (slider24CycleCount == 2) {
      text("KEEP SLIDING", width / 2, height / 1.2);
    } else if (slider24CycleCount ==3) {
      text("SLIDE ON BEAT=POINTS", width / 2, height / 1.2);
    } else if (slider24CycleCount >= 6) {
      text("RIGHT ON", width / 2, height / 1.2);
    }
  } else if (currentLevel == 5) {

    if (level5TriggerCount == 0) {
      text("NEW BUTTONS UNLCOKED", width / 2, height / 1.2);
    }  else if (level5TriggerCount >= 1 && level5TriggerCount <= 3) {
      text("SMASH THE PURPLE BUTTONS", width / 2, height / 1.2);
    } else if (level5TriggerCount >= 4 && level5TriggerCount <= 6) {
      text("REMEMBER ON BEAT", width / 2, height / 1.2);
    } else if (level5TriggerCount == 8 ) {
      text("THAT'S IT", width / 2, height / 1.2);
    } else if (level5TriggerCount >= 12) {
      text("THAT'S IT", width / 2, height / 1.2);
    }
  } else if (currentLevel == 6) {
    boolean anySliderComplete = false;
    for (int count : sliderCycleCount) {
      if (count >= requiredSliderCycles) {
        anySliderComplete = true;
        break;
      }
    }

    if (!anySliderComplete) {
      text("HORIZONTAL SLIDER = FX", width / 2, height / 1.2);
    } else {
      text("COWABANGA!", width / 2, height / 1.2);
    }
  } else if (currentLevel == 7) {
    text("FREESTYLE!", width / 2, height / 1.2);
  }
}

void displayFinalAssessment() {
    float mashRatio = (float) buttonMashCount / totalButtonPresses;
    float onBeatRatio = (float) onBeatPresses / totalButtonPresses;
    float sliderRatio = (float) totalSliderMovements / (totalButtonPresses + totalSliderMovements);

    textSize(30);
    fill(255,0,0);
    textAlign(CENTER, CENTER);

    if (mashRatio > 0.5 && onBeatRatio < 0.5 && totalButtonPresses > 50) {
        text("YOU SCORED HIGH, BUT YOU A BUTTON MASHER", width / 2, height / 2+240);
    } else if (totalButtonPresses < 50) {
        text("YOU A REAL MINIMALIST HUH", width / 2, height / 2+240);
    } else if (onBeatRatio > 0.6) {
        text("YOU ARE A TRUE VJ", width / 2, height / 2+240);
    } else if (mashRatio > 0.7 || onBeatRatio < 0.3) {
        text("YOURE SHIT MATE", width / 2, height / 2+240);
    } 
    //else if (sliderRatio > 0.6) {
    //    text("WE HAVE A SLIDER BOY OVER HERE", width / 2,height / 2+100);
    //} 
    else {
        text("GOOD JOB!", width / 2, height / 2+240);
    }
}

// ---------------------------------------------------------------------------
// Display big feedback for success or failure
// ---------------------------------------------------------------------------
void displayFeedback() {
  // Display FAIL text if the condition is met and the timer is active

  if ((currentLevel >= 3 && currentLevel <= 4 ) && (offsync)) {
    failwav.play();
  }
  if ((currentLevel >= 3 && currentLevel <= 4 ) && (offsync || (failDisplayStartTime != -1 && millis() - failDisplayStartTime < failDisplayDuration))) {
    textSize(150);
    fill(255, 0, 0);
    textAlign(CENTER, CENTER);
    text("BAD", width / 2, height / 2);


    if (offsync) {
      failDisplayStartTime = millis();
      offsync = false;
    }
  }
  // Display NICE text if the condition is met and the timer is active
  else if (isPressedBeatNICE || (niceDisplayStartTime != -1 && millis() - niceDisplayStartTime < niceDisplayDuration)) {
    textSize(150);
    fill(0, 255, 0);
    textAlign(CENTER, CENTER);
    text("NICE", width / 2, height / 2);

    if (isPressedBeatNICE) {
      niceDisplayStartTime = millis();
      isPressedBeatNICE = false;
    }
  } else {
    failDisplayStartTime = -1;
    niceDisplayStartTime = -1;
  }
}

// ---------------------------------------------------------------------------
// Checking if the current track looped
// ---------------------------------------------------------------------------
void checkTrackLoop() {
  SoundFile currentTrack = null;
  if (currentLevel == 1) currentTrack = level1Music;
  else if (currentLevel == 2) currentTrack = level2Music;
  else if (currentLevel == 3) currentTrack = level3Music;
  else if (currentLevel == 4) currentTrack = level4Music;
  else if (currentLevel == 5) currentTrack = level5Music;
  else if (currentLevel == 6) currentTrack = level6Music;
  else if (currentLevel == 7) currentTrack = level7Music;

  if (currentTrack != null) {
    float pos = currentTrack.position();
    if (pos < lastPos) {
      loopCount++;
      loopsSinceLevelStart++; // Increment the loop counter for the current level

      
      // Check if the user failed to meet the requirements within the allowed loops
      if (currentLevel<7 && loopsSinceLevelStart >= allowedLoops[currentLevel - 1]) {
        resetLevelProgress(); // Reset the trigger count and loop counter
      }
      println(pendingLevel);
      // If we have a pending level switch, finalize if we've reached the target
      if (pendingLevel > 0 && loopCount >= targetLoopCount) {
        finalizeLevelSwitch();
      }

      // Check if Level 7 has completed its loops
      if (currentLevel == 7 && loopsSinceLevelStart >= finalLevelLoops) {
        showEndScreen = true; // Show the end screen
        level7Music.stop(); // Stop the music
      }
      if (currentLevel == 7) {
        println(loopsSinceLevelStart);
      }
    }
    lastPos = pos;
  }
}

void resetLevelProgress() {
  println("Failed to meet requirements within " + allowedLoops[currentLevel - 1] + " loops. Resetting progress...");
  loopsSinceLevelStart = 0; // Reset the loop counter

  // Reset the trigger count for the current level
  if (currentLevel == 1) {
    triggerCount = 0;
  } else if (currentLevel == 2) {
    level2TriggerCount = 0;
  } else if (currentLevel == 3) {
    onBeatCount = 0;
  } else if (currentLevel == 4) {
    slider24CycleCount = 0;
  } else if (currentLevel == 5) {
    level5TriggerCount = 0;
  } else if (currentLevel == 6) {
    for (int i = 0; i < sliderCycleCount.length; i++) {
      sliderCycleCount[i] = 0;
    }
  }
}

// Display the end screen and leaderboard
void displayEndScreen() {
  background(0);
  textSize(100);
  fill(255);
  textAlign(CENTER, CENTER);
  text("END", width / 2, height / 3);

  // Create a list of scores
  int[] scores = {78, 35, 15, onBeatCount}; // christos, evripidis, BITCHBOY, YOU
  String[] names = {"christos", "evripidis", "BITCHBOY", "YOU"};

  // Sort scores in descending order
  for (int i = 0; i < scores.length - 1; i++) {
    for (int j = i + 1; j < scores.length; j++) {
      if (scores[i] < scores[j]) {
        // Swap scores
        int tempScore = scores[i];
        scores[i] = scores[j];
        scores[j] = tempScore;

        // Swap names
        String tempName = names[i];
        names[i] = names[j];
        names[j] = tempName;
      }
    }
  }

  // Display the sorted leaderboard
  textSize(40);
  float yOffset = height / 2; // Starting Y position for the leaderboard
  for (int i = 0; i < scores.length; i++) {
    if (names[i].equals("YOU")) {
      fill(255, 165, 0); // Orange color for "YOU"
    } else {
      fill(255); // White color for others
    }
    text(names[i] + ": " + scores[i], width / 2, yOffset);
    yOffset += 60; // Move down for the next entry
  }
  
  // Display final assessment
    displayFinalAssessment();
}

// ---------------------------------------------------------------------------
// Switch level after loop boundary
// ---------------------------------------------------------------------------
void finalizeLevelSwitch() {
  loopsSinceLevelStart = 0;
  if (pendingLevel == 2) {
    // L1 -> L2
    currentLevel = 2;
    println("=== ENTERING LEVEL 2 ===");
    level1Music.stop();
    level2Music.loop();
  } else if (pendingLevel == 3) {
    // L2 -> L3
    currentLevel = 3;
    println("=== ENTERING LEVEL 3 ===");
    level2Music.stop();
    level3Music.loop();
    beatDetector.input(level3Music);
  } else if (pendingLevel == 4) {
    // L3 -> L4
    currentLevel = 4;
    println("=== ENTERING LEVEL 4 ===");
    level3Music.stop();
    level4Music.loop();
    beatDetector.input(level4Music);
  } else if (pendingLevel == 5) {
    // L4 -> L5
    currentLevel = 5;
    println("=== ENTERING LEVEL 5 ===");
    level4Music.stop();
    level5Music.loop();
    beatDetector.input(level5Music);
    lvl5score = onBeatCount;
  } else if (pendingLevel == 6) {
    // L5 -> L6
    currentLevel = 6;
    println("=== ENTERING LEVEL 6 ===");
    level5Music.stop();
    level6Music.loop();
    beatDetector.input(level6Music);
  } else if (pendingLevel == 7 &&entered7) {
    // L6 -> L7
    currentLevel = 7;
    println("=== ENTERING LEVEL 7 ===");
    level6Music.stop();
    level7Music.loop();
    beatDetector.input(level7Music);
    entered7=false;
  }

  loopCount = 0;
  lastPos = 0;

  pendingLevel = -1;


  targetLoopCount = -1;
}
// ---------------------------------------------------------------------------
void beatDetection() {
  if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
    if (isPressedBeat) {
      onBeatCount++;

      isPressedBeat = false;
      isPressedBeatNICE  = false;
    }
    if (beatDetector.isBeat()) {
      lastBeatTime = millis(); // Update the last beat time
    }
    //background(255, 100, 0); // Turn the screen green
    if (currentLevel==3 && onBeatCount<=4) {
      noStroke();
      circle(width/2, height/2, 100);
    }
  }
}
// ---------------------------------------------------------------------------
// MIDI noteOn
// ---------------------------------------------------------------------------
void noteOn(int channel, int pitch, int velocity) {
  if (midiCooldownActive && millis() < midiCooldownEndTime) {
    println("MIDI cooldown active. Ignoring message.");
    return; // Ignore messages during cooldown
  }

  long currentTime = millis();
  if (currentTime - lastMidiMessageTime < midiMessageCooldown) {
    println("MIDI message too fast. Ignoring.");
    return; // Ignore messages that arrive too quickly
  }

  // Track message frequency
  if (currentTime - midiMessageWindowStart > midiMessageWindowDuration) {
    // Reset the counter if the window has expired
    midiMessageCounter = 0;
    midiMessageWindowStart = currentTime;
  }
  midiMessageCounter++;

  // If too many messages are received within the window, activate cooldown
  if (midiMessageCounter > midiMessageThreshold) {
    println("Too many MIDI messages detected. Activating cooldown.");
    midiCooldownActive = true;
    midiCooldownEndTime = currentTime + midiCooldownDuration;
    return; // Ignore further messages
  }

  lastMidiMessageTime = currentTime; // Update the last message time
  try {
    isPressed = true;

 // Track total button presses
    totalButtonPresses++;

    // Track button mashing
    long currentTime2 = millis();
    if (currentTime2 - lastButtonPressTime < buttonMashWindow) {
        buttonMashCount++; // Increment mash count if presses are too close together
    }
    lastButtonPressTime = currentTime2;

    // Track on-beat presses
    if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
        onBeatPresses++;
    }


    // Level 1 => only pitch=52
    if (currentLevel == 1) {
      if (pitch != activeButton1) return;
      if (!isTriggered) {
        isTriggered = true;
        triggerCount++;


        if (triggerCount >= 3 && pendingLevel < 0) {
          pendingLevel    = 2;
          targetLoopCount = loopCount + 1;
        }
      }
    }
    // Level 2 => row {52..55,84..87}, 4 presses
    else if (currentLevel == 2) {
      if (!isInRow2(pitch)) return;
      level2TriggerCount++;

      if (level2TriggerCount >= required2Triggers && pendingLevel < 0) {
        pendingLevel    = 3;
        targetLoopCount = loopCount + 1;
      }
    }
    // Level 3 => row {52..55,84..87}, 8 presses
    else if (currentLevel == 3) {
      if (!isInRow2(pitch)) return;
      if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
        isPressedBeat = true; // Mark that the button was pressed on beat
        isPressedBeatNICE=true;
      }

      if (!(beatDetector.isBeat() || millis() - lastBeatTime < beatWindow)) {
        offsync = true; // Mark that the button was pressed on beat
      }

      if (onBeatCount >= required3Triggers && pendingLevel < 0) {
        pendingLevel    = 4;
        targetLoopCount = loopCount + 1;
      }
    }
    // Level 4 => row {52..55,84..87}, 8 presses
    else if (currentLevel == 4) {


      if (!isInRow2(pitch)) return;
      if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
        isPressedBeat = true; // Mark that the button was pressed on beat
        isPressedBeatNICE=true;
      }

      if (!(beatDetector.isBeat() || millis() - lastBeatTime < beatWindow)) {
        offsync = true; // Mark that the button was pressed on beat
      }
    } else if ( currentLevel==5) {
      if (isInRow5top(pitch)) {

        level5TriggerCount++;
        //onBeatCount++;
        if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
          isPressedBeat = true; // Mark that the button was pressed on beat
          isPressedBeatNICE=true;
        }

        if (!(beatDetector.isBeat() || millis() - lastBeatTime < beatWindow)) {
          offsync = true; // Mark that the button was pressed on beat
        }
        if (level5TriggerCount >= required5Triggers && pendingLevel < 0) {
          pendingLevel = 6;
          targetLoopCount = loopCount + 1;
        }
      }



      //if (!isInRow5(pitch)) return;
    } else if ( currentLevel>=6) {

      if (isInRow5top(pitch) || isInRow2(pitch)) {
        if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
          isPressedBeat = true; // Mark that the button was pressed on beat
          isPressedBeatNICE=true;
        }

        if (!(beatDetector.isBeat() || millis() - lastBeatTime < beatWindow)) {
          offsync = true; // Mark that the button was pressed on beat
        }
      }
    }

    // If mapped to Resolume, send OSC
    if (midiToOscMapping.containsKey(pitch)) {
      sendOscMessage(midiToOscMapping.get(pitch));
    }
    sendMidiFeedback(pitch, 127);
  }
  catch (Exception e) {
    println("Error in noteOn: " + e.getMessage());
    initializeMidi(); // Attempt to reinitialize the MIDI device
  }
}

boolean isInRow5top(int p) {
  for (int val : row5top) {
    if (p == val) return true;
  }
  return false;
}

void noteOff(int channel, int pitch, int velocity) {
  println("Note Off - Channel: " + channel + ", Pitch: " + pitch + ", Velocity: " + velocity);
  if (midiCooldownActive && millis() < midiCooldownEndTime) {
    println("MIDI cooldown active. Ignoring message.");
    return; // Ignore messages during cooldown
  }

  long currentTime = millis();
  if (currentTime - lastMidiMessageTime < midiMessageCooldown) {
    println("MIDI message too fast. Ignoring.");
    return; // Ignore messages that arrive too quickly
  }

  // Track message frequency
  if (currentTime - midiMessageWindowStart > midiMessageWindowDuration) {
    // Reset the counter if the window has expired
    midiMessageCounter = 0;
    midiMessageWindowStart = currentTime;
  }
  midiMessageCounter++;

  // If too many messages are received within the window, activate cooldown
  if (midiMessageCounter > midiMessageThreshold) {
    println("Too many MIDI messages detected. Activating cooldown.");
    midiCooldownActive = true;
    midiCooldownEndTime = currentTime + midiCooldownDuration;
    return; // Ignore further messages
  }

  lastMidiMessageTime = currentTime; // Update the last message time
  try {
    offsync = false;
    isPressed = false;
    isPressedBeat = false;
    isPressedBeatNICE = false;

    if (currentLevel == 1 && isTriggered && pitch == activeButton1) {
      isTriggered = false;
    }

    if (midiToOscMapping.containsKey(pitch)) {
      sendOscMessage0(midiToOscMapping.get(pitch));
    }

    sendMidiFeedback(pitch, 1);
  }
  catch (Exception e) {
    println("Error in noteOff: " + e.getMessage());
    initializeMidi(); // Attempt to reinitialize the MIDI device
  }
}

// Helper function for row {52..55,84..87}
boolean isInRow2(int p) {
  for (int val : row2) {
    if (p == val) return true;
  }
  return false;
}
boolean isInRow5(int p) {
  for (int val : row5) {
    if (p == val) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Controller Change (Encoders/Sliders)
// ---------------------------------------------------------------------------
void controllerChange(int channel, int control, int value) {
  //if (millis() - lastMessageTime < messageInterval) return;  // Prevent spam
  //lastMessageTime = millis();
  //if (millis() - lastMessageTime < messageInterval) return;  // Prevent spam
  //lastMessageTime = millis();
  //println("Controller Change - Channel: " + channel + ", Control: " + control + ", Value: " + value);
  if (midi == null) {
    println("MIDI device not initialized. Skipping controller change.");
    return;
  }

  //if (midiCooldownActive && millis() < midiCooldownEndTime) {
  //  println("MIDI cooldown active. Ignoring message.");
  //  return; // Ignore messages during cooldown
  //}

  //long currentTime = millis();
  //if (currentTime - lastMidiMessageTime < midiMessageCooldown) {
  //  println("MIDI message too fast. Ignoring.");
  //  return; // Ignore messages that arrive too quickly
  //}

  //// Track message frequency
  ////if (currentTime - midiMessageWindowStart > midiMessageWindowDuration) {
  ////  // Reset the counter if the window has expired
  ////  midiMessageCounter = 0;
  ////  midiMessageWindowStart = currentTime;
  ////}
  ////midiMessageCounter++;

  ////// If too many messages are received within the window, activate cooldown
  ////if (midiMessageCounter > midiMessageThreshold) {
  ////  println("Too many MIDI messages detected. Activating cooldown.");
  ////  midiCooldownActive = true;
  ////  midiCooldownEndTime = currentTime + midiCooldownDuration;
  ////  return; // Ignore further messages
  ////}

  //lastMidiMessageTime = currentTime; // Update the last message time


  try {
    // For Levels < 4 => block all controllers
    if (currentLevel < 4) {
      return;
    }

    // For Level 4 => only slider #24 is active
    if (currentLevel == 4) {
      if (control != 24) {
        return;
      }
    }
    // Track slider movements
    if (control >= 20 && control <= 24) {
        totalSliderMovements++;
    }

    // For Level 5 => block sliders 20-23
    if (currentLevel == 5 && control >= 20 && control <= 23) {
      return;
    }

    float oscValue;
    boolean isLooping = false;

    // Encoders 0..7
    if (control >= 0 && control <= 7) {
      if (value == 1)      oscValue = 0.05;
      else if (value == 127) oscValue = -0.05;
      else return;

      // Some encoders wrap
      if (control == 1 || control == 2 || control == 0 || control == 6 || control == 7) {
        isLooping = true;
      }
      loopValues[control] += oscValue;
      if (isLooping) {
        if (loopValues[control] > 1.0) loopValues[control] = 0.0;
        if (loopValues[control] < 0.0) loopValues[control] = 1.0;
      } else {
        if (loopValues[control] > 1.0) loopValues[control] = 1.0;
        if (loopValues[control] < 0.0) loopValues[control] = 0.0;
      }
      oscValue = loopValues[control];
      //if (bonusLevelUnlocked) {
      //  onBeatCount += bonusLevelMultiplier;
      //}
    } else {
      // Sliders
      oscValue = map(value, 0, 127, 0, 1);
      if (control >= 20 && control <= 23) {
        // invert
        oscValue = map(value, 0, 127, 1, 0);
      }
    }

    // Special logic for slider #24 in Level 4
    if (currentLevel >= 4 && control == 24) {
      // Detect when the slider crosses 0 or 127
      if (value == 0 && !slider24AtMin) {
        slider24AtMin = true; // Mark that the slider is at the minimum
        if (slider24AtMax) {
          slider24CycleCount++; // Increment cycle count if coming from the maximum
          slider24AtMax = false; // Reset the maximum flag
        }

        // Check if this action is on beat
        if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
          onBeatCount++;
          isPressedBeatNICE=true;
        }
      } else if (value == 127 && !slider24AtMax) {
        slider24AtMax = true; // Mark that the slider is at the maximum
        if (slider24AtMin) {
          slider24CycleCount++; // Increment cycle count if coming from the minimum
          slider24AtMin = false; // Reset the minimum flag
        }

        // Check if this action is on beat
        if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
          onBeatCount++;
          isPressedBeatNICE=true;
        }
      }

      // Check if the required number of cycles is reached
      if (slider24CycleCount >= 6 && pendingLevel < 0 && currentLevel ==4) {
        pendingLevel = 5;
        targetLoopCount = loopCount + 1;
      }

      // Send OSC specifically for slider #24
      sendOscMessageWithValue("/composition/layers/1/video/opacity", oscValue);
    }

    // For Level 6 => handle sliders 20-23
    if (currentLevel >= 6 && (control >= 20 && control <= 23)) {
      int sliderIndex = control - 20; // Map control number to array index (0-3)

      // Detect when the slider crosses 0 or 127
      if (value == 0 && !sliderAtMin[sliderIndex]) {
        sliderAtMin[sliderIndex] = true; // Mark that the slider is at the minimum
        if (sliderAtMax[sliderIndex]) {
          sliderCycleCount[sliderIndex]++; // Increment cycle count if coming from the maximum
          sliderAtMax[sliderIndex] = false; // Reset the maximum flag
        }
        // Check if this action is on beat
        if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
          onBeatCount++;
          isPressedBeatNICE=true;
        }
      } else if (value == 127 && !sliderAtMax[sliderIndex]) {
        sliderAtMax[sliderIndex] = true; // Mark that the slider is at the maximum
        if (sliderAtMin[sliderIndex]) {
          sliderCycleCount[sliderIndex]++; // Increment cycle count if coming from the minimum
          sliderAtMin[sliderIndex] = false; // Reset the minimum flag
        }
        // Check if this action is on beat
        if (beatDetector.isBeat() || millis() - lastBeatTime < beatWindow) {
          onBeatCount++;
          isPressedBeatNICE=true;
        }
      }

      // Check if any slider has completed the required number of cycles
      if (((sliderCycleCount[sliderIndex] >= requiredSliderCycles) && pendingLevel < 0) && entered7) {
        pendingLevel = 7; // Set pending level to 7
        targetLoopCount = loopCount + 1; // Transition at the next loop boundary
      }
    }

    // Send OSC for other controls
    String address = getOscAddressForControl(control);
    if (address != null) {
      sendOscMessageWithValue(address, oscValue);
    }
  }
  catch (Exception e) {
    println("Error in controllerChange: " + e.getMessage());
    initializeMidi(); // Attempt to reinitialize the MIDI device
  }
}
//aaa
String getOscAddressForControl(int control) {
  switch (control) {
  case 20:
    return "/composition/video/effects/warpspeed/opacity";
  case 21:
    return "/composition/video/effects/stingysphere/opacity";
  case 22:
    return "/composition/video/effects/recolour/opacity";
  case 23:
    return "/composition/video/effects/colorize/opacity";
  case 24:
    return "/composition/layers/1/video/opacity";

  case 25:
    return "/composition/layers/2/video/opacity";
  case 26:
    return "/composition/layers/3/video/opacity";
  case 27:
    return "/composition/layers/4/video/opacity";

    // Encoders
  case 0:
    return "/composition/video/effects/colorize/effect/color/hue";
  case 1:
    return "/composition/video/effects/recolour/effect/palette";
  case 2:
    return "/composition/video/effects/stingysphere/effect/rotatex";
  case 3:
    return "/composition/video/effects/warpspeed/effect/scale";
  case 4:
    return "/composition/video/effects/colorize/effect/color/brightness";
  case 5:
    return "/composition/video/effects/recolour/effect/cyclespeed";
  case 6:
    return "/composition/video/effects/stingysphere/effect/rotatey";
  case 7:
    return "/composition/video/effects/warpspeed/effect/rotate";
  default:
    return null;
  }
}

// ---------------------------------------------------------------------------
// UI / Utility
// ---------------------------------------------------------------------------
void lightUpButtons() {
  // Light up relevant buttons per level, if not currently pressed
  if (!isPressed) {
    if (currentLevel == 1) {
      // Light up button 52
      sendMidiFeedback(52, 32);
    } else if (currentLevel == 2 || currentLevel == 3 || currentLevel == 4) {
      // Light up row
      for (int i : row2) {
        sendMidiFeedback(i, 32);
      }
    } else if (currentLevel == 5) {
      for (int i : row2) {
        sendMidiFeedback(i, 32);
      }
      for (int i : row5top) {
        sendMidiFeedback(i, 107);
      }
    } else if (currentLevel == 6 ||currentLevel == 7 ) {
      // Light up all buttons
      for (int i : row2) {
        sendMidiFeedback(i, 32);
      }
      for (int i : row5top) {
        sendMidiFeedback(i, 107);
      }
    }
  }
}

// ---------------------------------------------------------------------------
void initializeMidi() {
  try {
    MidiBus.list(); // List available MIDI devices
    midi = new MidiBus(this, "Pico 2", "Pico 2"); // Reinitialize the MIDI device
    println("MIDI device initialized.");
  }
  catch (Exception e) {
    println("Failed to initialize MIDI device: " + e.getMessage());
    midi = null; // Set to null to avoid further errors
  }
}
void sendOscMessage(String address) {
  OscMessage msg = new OscMessage(address);
  msg.add(1);
  oscP5.send(msg, resolume);
}
void sendOscMessage0(String address) {
  OscMessage msg = new OscMessage(address);
  msg.add(0);
  oscP5.send(msg, resolume);
}

void sendOscMessageWithValue(String address, float value) {
  OscMessage msg = new OscMessage(address);
  msg.add(value);
  oscP5.send(msg, resolume);
}
void sendMidiFeedback(int note, int velocity) {
  long currentTime = millis();
  if (currentTime - lastMidiSendTime < midiSendInterval) {
    return; // Skip if messages are being sent too quickly
  }

  try {
    if (midi != null) {
      midi.sendNoteOn(0, note, velocity);
    } else {
      println("MIDI device not initialized. Skipping send.");
    }
  }
  catch (Exception e) {
    println("Error sending MIDI message: " + e.getMessage());
    initializeMidi(); // Attempt to reinitialize the MIDI device
  }
}
