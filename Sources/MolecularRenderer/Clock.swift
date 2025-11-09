#if os(macOS)
import QuartzCore
import CoreVideo
#else
import SwiftCOM
import WinSDK
#endif

struct TimeStamp {
  // The Mach continuous time or QPC time for now.
  var host: Int
  
  #if os(macOS)
  // The Core Video time for when the frame will be presented.
  var video: Int
  #else
  // The present count from DXGI frame statistics.
  var presentCount: Int
  #endif
  
  #if os(macOS)
  var refreshPeriod: Int
  #endif
  
  init(frameStatistics: Clock.FrameStatistics) {
    #if os(macOS)
    self.host = Int(mach_continuous_time())
    #else
    var largeInteger = LARGE_INTEGER()
    QueryPerformanceCounter(&largeInteger)
    self.host = Int(largeInteger.QuadPart)
    #endif
    
    #if os(macOS)
    self.video = Int(frameStatistics.videoTime)
    self.refreshPeriod = Int(frameStatistics.videoRefreshPeriod)
    #else
    if let frameStatistics {
      self.presentCount = Int(frameStatistics.PresentCount)
    } else {
      self.presentCount = 0
    }
    #endif
  }
}

fileprivate struct ClockTimeStamps {
  var start: TimeStamp
  var previous: TimeStamp
}

public struct Clock {
  #if os(macOS)
  typealias FrameStatistics = CVTimeStamp
  #else
  typealias FrameStatistics = DXGI_FRAME_STATISTICS?
  #endif
  
  var frameCounter: Int
  var frameRate: Int
  private var timeStamps: ClockTimeStamps?
  #if os(macOS)
  private var refreshPeriod: Int?
  #endif
  
  #if os(Windows)
  var isInitializing: Bool = true
  #endif
  var sustainedMisalignmentDuration: Int = .zero
  var sustainedMisalignedValue: Int = .zero
  
  init(display: Display) {
    frameCounter = .zero
    frameRate = display.frameRate
  }
  
  private func frames(ticks: Int) -> Int {
    #if os(macOS)
    guard let refreshPeriod else {
      fatalError("Refresh period was not initialized.")
    }
    
    // This should be exactly 24 MHz on most macOS devices. The M1 MacBook Air
    // is 399984 * 60 = 23999040.
    let ticksPerSecond = refreshPeriod * frameRate
    guard ticksPerSecond > 23_000_000,
          ticksPerSecond < 25_000_000 else {
      fatalError("Unexpected ticks per second.")
    }
    
    #else
    let ticksPerSecond: Int = 10_000_000
    #endif
    
    let seconds = Double(ticks) / Double(ticksPerSecond)
    var frames = seconds * Double(frameRate)
    frames = frames.rounded(.toNearestOrEven)
    return Int(frames)
  }
  
  #if os(macOS)
  private func isDivisible(ticks: Int) -> Bool {
    guard let refreshPeriod else {
      fatalError("Refresh period was not initialized.")
    }
    return ticks % refreshPeriod == 0
  }
  #endif
  
  mutating func increment(frameStatistics: FrameStatistics) {
    guard let timeStamps else {
      let start = TimeStamp(frameStatistics: frameStatistics)
      self.timeStamps = ClockTimeStamps(
        start: start,
        previous: start)
      #if os(macOS)
      self.refreshPeriod = start.refreshPeriod
      #endif
      return
    }
    
    let start = timeStamps.start
    let previous = timeStamps.previous
    let current = TimeStamp(frameStatistics: frameStatistics)
    incrementFrameCounter(
      start: start,
      previous: previous,
      current: current)
    
    #if os(Windows)
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
    #endif
    
    self.timeStamps!.previous = current
  }
  
  private mutating func incrementFrameCounter(
    start: TimeStamp,
    previous: TimeStamp,
    current: TimeStamp
  ) {
    // Option to return early on Windows.
    let targetCounter = frames(ticks: current.host - start.host)
    #if os(Windows)
    if isInitializing {
      frameCounter = targetCounter
      return
    }
    #endif
    
    #if os(macOS)
    // Validate that all time stamps use the same refresh period.
    guard start.refreshPeriod == previous.refreshPeriod,
          start.refreshPeriod == current.refreshPeriod else {
      fatalError("Vsync timestamps had different refresh periods.")
    }
    
    // Validate that the vsync timestamp is divisible by the refresh period.
    let currentVideoTicks = current.video - start.video
    guard isDivisible(ticks: currentVideoTicks) else {
      fatalError("Vsync timestamp is not divisible by refresh period.")
    }
    
    // Validate that the vsync timestamp is monotonically increasing.
    let previousVsyncFrame = frames(ticks: previous.video - start.video)
    let currentVsyncFrame = frames(ticks: current.video - start.video)
    guard currentVsyncFrame > previousVsyncFrame else {
      fatalError("Vsync timestamp is not monotonically increasing.")
    }
    #else
    // Fetch the vsync timestamp, which may not increase from frame to frame.
    let previousVsyncFrame = previous.presentCount - start.presentCount
    let currentVsyncFrame = current.presentCount - start.presentCount
    #endif
    
    // Predict the next frame.
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
