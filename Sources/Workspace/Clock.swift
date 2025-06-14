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
      video = Int(frameStatistics.PresentCount) * 10_000_000
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
    
    incrementFrameCounter(
      start: timeStamps.start,
      previous: timeStamps.previous,
      current: current)
    
    self.timeStamps!.previous = current
  }
  
  mutating func incrementFrameCounter(
    start: TimeStamp,
    previous: TimeStamp,
    current: TimeStamp
  ) {
    // Fetch the vsync timestamp, which may not increase from frame to frame.
    let previousVsyncFrame = frames(ticks: previous.video - start.video)
    let currentVsyncFrame = frames(ticks: current.video - start.video)
    
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
