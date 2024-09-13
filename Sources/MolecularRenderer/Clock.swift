import QuartzCore

struct TimeStamp {
  // The Mach continuous time for now.
  var host: UInt64
  
  // The Core Video time for when the frame will be presented.
  var video: UInt64
  
  init(vsyncTimeStamp: CVTimeStamp) {
    host = mach_continuous_time()
    video = UInt64(truncatingIfNeeded: vsyncTimeStamp.videoTime)
  }
}

public class Clock {
  var start: TimeStamp?
  var latest: TimeStamp?
  
  public init() {
    
  }
  
  public func increment(
    display: Display,
    vsyncTimeStamp: CVTimeStamp
  ) {
    let current = TimeStamp(vsyncTimeStamp: vsyncTimeStamp)
    guard let start,
          let previous = latest else {
      self.start = current
      self.latest = current
      return
    }
    
    // Validate that the vsync frame index is an integer multiple.
    do {
      let currentTimeTicks = current.video - start.video
      let currentTimeSeconds = Double(currentTimeTicks) / 24_000_000
      let currentTimeFrames = currentTimeSeconds * Double(display.frameRate)
      
      let roundedTimeFrames = rint(currentTimeFrames)
      let remainderTimeFrames = currentTimeFrames - roundedTimeFrames
      guard remainderTimeFrames.magnitude < 0.001 else {
        fatalError("Vsync timestamp was not integer multiple of refresh rate.")
      }
    }
    
    // Store the current timestamp as the latest.
    self.latest = current
  }
}

extension Clock {
  /// The true wall time since rendering started.
  ///
  /// We will eventually replace this with an approximate wall time, as the
  /// frames will be jittery.
  public var seconds: Double {
    guard let start,
          let latest else {
      fatalError("Timestamps were not set.")
    }
    
    let latestTimeTicks = latest.host - start.host
    let latestTimeSeconds = Double(latestTimeTicks) / 24_000_000
    return latestTimeSeconds
  }
  
  /// The current estimate of the discrete multiple of the display's refresh
  /// period.
  public func frames(display: Display) -> Int {
    guard let start,
          let latest else {
      fatalError("Timestamps were not set.")
    }
    
    let latestTimeTicks = latest.video - start.video
    let latestTimeSeconds = Double(latestTimeTicks) / 24_000_000
    let latestTimeFrames = latestTimeSeconds * Double(display.frameRate)
    
    let roundedTimeFrames = rint(latestTimeFrames)
    return Int(roundedTimeFrames)
  }
}
