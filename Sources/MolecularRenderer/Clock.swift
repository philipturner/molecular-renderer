#if os(macOS)
import QuartzCore
#else
import SwiftCOM
import WinSDK
#endif

struct TimeStamp {
  #if os(macOS)
  // The Mach continuous time for now.
  var host: Int
  #else
  // The QPC time for now.
  var host: Int
  #endif
  
  #if os(macOS)
  // The Core Video time for when the frame will be presented.
  var video: Int
  #else
  // The present count from DXGI frame statistics.
  var presentCount: Int
  #endif
  
  #if os(macOS)
  init(vsyncTimeStamp: CVTimeStamp) {
    host = Int(mach_continuous_time())
    video = Int(vsyncTimeStamp.videoTime)
  }
  #else
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
  #endif
}

struct ClockTimeStamps {
  var start: TimeStamp
  var latest: TimeStamp
}

#if os(macOS)
public struct Clock {
  var frameCounter: Int
  var frameRate: Int
  var timeStamps: ClockTimeStamps?
  
  var sustainedMisalignmentDuration: Int = .zero
  var sustainedMisalignedValue: Int = .zero
  
  init(display: Display) {
    frameCounter = .zero
    frameRate = display.frameRate
  }
  
  func frames(ticks: Int) -> Int {
    let seconds = Double(ticks) / 24_000_000
    var frames = seconds * Double(frameRate)
    frames = frames.rounded(.toNearestOrEven)
    return Int(frames)
  }
  
  mutating func increment(
    vsyncTimeStamp: CVTimeStamp
  ) {
    guard let timeStamps else {
      let timeStamp = TimeStamp(vsyncTimeStamp: vsyncTimeStamp)
      self.timeStamps = ClockTimeStamps(
        start: timeStamp,
        latest: timeStamp)
      return
    }
    
    let start = timeStamps.start
    let previous = timeStamps.latest
    let current = TimeStamp(vsyncTimeStamp: vsyncTimeStamp)
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
    // Validate that the vsync timestamp is divisible by the refresh period.
    do {
      let currentVideoTicks = current.video - start.video
      let refreshPeriod = 24_000_000 / frameRate
      guard currentVideoTicks % refreshPeriod == 0 else {
        fatalError("Vsync timestamp is not divisible by refresh period.")
      }
    }
    
    // Validate that the vsync timestamp is monotonically increasing.
    let previousVsyncFrame = frames(ticks: previous.video - start.video)
    let currentVsyncFrame = frames(ticks: current.video - start.video)
    guard currentVsyncFrame > previousVsyncFrame else {
      fatalError("Vsync timestamp is not monotonically increasing.")
    }
    
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

extension Clock {
  /// The current estimate of the discrete multiple of the display's refresh
  /// period.
  public var frames: Int {
    frameCounter
  }
}
#endif
