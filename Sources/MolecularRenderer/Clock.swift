import QuartzCore

struct TimeStamp {
  // The Mach continuous time for now.
  var host: Int
  
  // The Core Video time for when the frame will be presented.
  var video: Int
  
  init(vsyncTimeStamp: CVTimeStamp) {
    host = Int(mach_continuous_time())
    video = Int(vsyncTimeStamp.videoTime)
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
    let previousFrameID = frames(ticks: previous.video - start.video)
    let currentFrameID = frames(ticks: current.video - start.video)
    guard currentFrameID > previousFrameID else {
      fatalError("Vsync timestamp is not monotonically increasing.")
    }
    
    // Generate the target frame ID.
    let targetFrameID = frames(ticks: current.host - start.host)
    
    // Generate the frame delta.
    var frameDelta = currentFrameID - previousFrameID
    let misalignment = targetFrameID - (frameCounter + frameDelta)
    if misalignment.magnitude >= 2 {
      print("Exponential gravitation: \(frameDelta) -> \(frameDelta + misalignment / 2)")
      frameDelta += misalignment / 2
    }
    
    // Update the frame counter.
    frameCounter = frameCounter + frameDelta
    print("\(frameCounter - targetFrameID) | \(frameDelta)")
  }
}

extension Clock {
  /// The current estimate of the discrete multiple of the display's refresh
  /// period.
  public var frames: Int {
    frameCounter
  }
}
