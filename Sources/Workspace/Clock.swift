#if os(Windows)
import SwiftCOM
import WinSDK

struct TimeStamp {
  // The QPC time for now.
  var host: Int
  
  // The present count from DXGI frame statistics.
  var presentCount: Int
  
  init(frameStatistics: DXGI_FRAME_STATISTICS?) {
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    host = Int(largeInteger.QuadPart)
    
    if let frameStatistics {
      presentCount = Int(frameStatistics.PresentCount)
    } else {
      presentCount = 0
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
    let ticksPerSecond: Int = 10_000_000
    let seconds = Double(ticks) / Double(ticksPerSecond)
    var frames = seconds * Double(frameRate)
    frames = frames.rounded(.toNearestOrEven)
    return Int(frames)
  }
  
  mutating func increment(
    frameStatistics: DXGI_FRAME_STATISTICS?
  ) {
    guard let timeStamps else {
      let start = TimeStamp(frameStatistics: frameStatistics)
      self.timeStamps = ClockTimeStamps(
        start: start,
        previous: start)
      return
    }
    
    let start = timeStamps.start
    let previous = timeStamps.previous
    let current = TimeStamp(frameStatistics: frameStatistics)
    incrementFrameCounter(
      start: start,
      previous: previous,
      current: current)
    
    if isInitializing,
       current.presentCount > 0 {
      guard current.presentCount < 10 else {
        fatalError("May be tracking intervals since the computer booted.")
      }
      
      // Wait for a small period, to ensure the GPU's present queue has
      // stabilized.
      if current.presentCount >= 5 {
        self.isInitializing = false
      }
    }
    
    self.timeStamps!.previous = current
  }
  
  mutating func incrementFrameCounter(
    start: TimeStamp,
    previous: TimeStamp,
    current: TimeStamp
  ) {
    // Fetch the vsync timestamp, which may not increase from frame to frame.
    let previousVsyncFrame = previous.presentCount - start.presentCount
    let currentVsyncFrame = current.presentCount - start.presentCount
    
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
    if (currentVsyncFrame - previousVsyncFrame) != 1 {
      print(targetCounter, frameCounter, nextCounter)
    }
    if isInitializing {
      frameCounter = targetCounter
    } else {
      frameCounter = nextCounter
    }
  }
}

#endif
