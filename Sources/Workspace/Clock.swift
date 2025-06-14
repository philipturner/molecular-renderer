#if os(Windows)
import SwiftCOM
import WinSDK

struct TimeStamp {
  // The QPC time for now.
  var host: Int
  
  // The present count from DXGI frame statistics.
  var video: Int
  
  init(frameStatistics: DXGI_FRAME_STATISTICS?) {
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    host = Int(largeInteger.QuadPart)
    
    if let frameStatistics {
      video = Int(frameStatistics.PresentCount)
    } else {
      video = 0
    }
  }
}

struct ClockTimeStamps {
  var start: TimeStamp
  var previous: TimeStamp
}

public struct Clock {
  var frameCounter: Int
  var frameRate: Int
  var timeStamps: ClockTimeStamps?
  
  var isInitializing: Bool = true
  var sustainedMisalignmentDuration: Int = .zero
  var sustainedMisalignedValue: Int = .zero
  
  init() {
    frameCounter = .zero
    frameRate = 60
  }
  
  func frames(ticks: Int) -> Int {
    let seconds = Double(ticks) / 10_000_000
    var frames = seconds * Double(frameRate)
    frames = frames.rounded(.toNearestOrEven)
    return Int(frames)
  }
  
  mutating func increment(
    frameStatistics: DXGI_FRAME_STATISTICS?
  ) {
    let current = TimeStamp(frameStatistics: frameStatistics)
    guard let timeStamps else {
      self.timeStamps = ClockTimeStamps(
        start: current,
        previous: current)
      return
    }
    
    if isInitializing {
      // Increment frame counter based on host time.
      incrementFrameCounter(
        start: timeStamps.start,
        previous: timeStamps.previous,
        current: current)
      
      // While initialization is complete, video time n - 1 is not valid.
      // Only permit use of video times on the next function call after
      // this one (n and n + 1).
      if current.video > 0 {
        guard current.video <= 3 else {
          fatalError("""
            DXGI may be tracking present intervals since the computer booted.
            """)
        }
        
        self.isInitializing = false
      }
    } else {
      // Increment frame counter based on difference between last two video
      // times.
      incrementFrameCounter(
        start: timeStamps.start,
        previous: timeStamps.previous,
        current: current)
    }
    
    self.timeStamps!.previous = current
  }
  
  mutating func incrementFrameCounter(
    start: TimeStamp,
    previous: TimeStamp,
    current: TimeStamp
  ) {
    // Fetch the vsync timestamp, which may not increase from frame to frame.
    let previousVsyncFrame = previous.video - start.video
    let currentVsyncFrame = current.video - start.video
    
    // Predict the next frame.
    let targetCounter = frames(ticks: current.host - start.host)
    var nextCounter = frameCounter + (currentVsyncFrame - previousVsyncFrame)
    var nextMisalignmentDuration: Int = .zero
    
    // Correct for the error in the prediction.
    if (targetCounter - nextCounter).magnitude >= 2 {
      nextCounter += (targetCounter - nextCounter) / 2
    } else if (targetCounter - nextCounter).magnitude == 1 {
      if sustainedMisalignmentDuration >= 10 {
        nextCounter = targetCounter
      } else if (targetCounter - nextCounter) == sustainedMisalignedValue {
        nextMisalignmentDuration = sustainedMisalignmentDuration + 1
      }
    }
    
    // Update the two state variables for noise-free alignment with the wall
    // clock time.
    sustainedMisalignmentDuration = nextMisalignmentDuration
    sustainedMisalignedValue = targetCounter - nextCounter
    
    // Update the frame counter.
    frameCounter = nextCounter
  }
}

#endif
