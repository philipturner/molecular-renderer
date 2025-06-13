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
  var latest: TimeStamp
}

public struct Clock {
  var frameCounter: Int
  var frameRate: Int
  var timeStamps: ClockTimeStamps?
  
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
    guard let timeStamps else {
      let timeStamp = TimeStamp(frameStatistics: frameStatistics)
      self.timeStamps = ClockTimeStamps(
        start: timeStamp,
        latest: timeStamp)
      return
    }
    
    let start = timeStamps.start
    let previous = timeStamps.latest
    let current = TimeStamp(frameStatistics: frameStatistics)
    incrementFrameCounter(
      start: start,
      previous: previous,
      current: current)
    
    self.timeStamps!.latest = current
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
