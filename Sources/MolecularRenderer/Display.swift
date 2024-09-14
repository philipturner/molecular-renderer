import AppKit

public struct DisplayDescriptor {
  public var renderTargetSize: Int?
  public var screenID: Int?
  
  public init() {
    
  }
}

public class Display {
  /// The resolution of the rendering region, in pixels.
  public private(set) var renderTargetSize: Int
  
  /// The display chosen for rendering at program startup.
  public private(set) var screen: NSScreen
  
  public init(descriptor: DisplayDescriptor) {
    guard let renderTargetSize = descriptor.renderTargetSize,
          let screenID = descriptor.screenID else {
      fatalError("Descriptor was incomplete.")
    }
    self.renderTargetSize = renderTargetSize
    self.screen = Display.screen(screenID: screenID)
  }
}

extension Display {
  public static func screenID(screen: NSScreen) -> Int {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    let screenNumberAny = screen.deviceDescription[key]!
    let screenNumberNSNumber = screenNumberAny as! NSNumber
    let screenNumber = screenNumberNSNumber.uint32Value
    return Int(screenNumber)
  }
  
  public static func screen(screenID: Int) -> NSScreen {
    let screens = NSScreen.screens
    
    var matchedScreen: NSScreen?
    for screen in screens {
      let candidateScreenID = Display.screenID(screen: screen)
      if screenID == candidateScreenID {
        matchedScreen = screen
      }
    }
    
    guard let matchedScreen else {
      fatalError("Failed to find screen matching ID: \(screenID)")
    }
    return matchedScreen
  }
  
  public static func findFastestScreen() -> NSScreen {
    let screens = NSScreen.screens
    
    var fastestScreen: NSScreen?
    var fastestFrameRate: Int = .zero
    for screen in screens {
      let candidateFrameRate = screen.maximumFramesPerSecond
      if candidateFrameRate > fastestFrameRate {
        fastestScreen = screen
        fastestFrameRate = candidateFrameRate
      }
    }
    
    guard let fastestScreen else {
      fatalError("Failed to find fastest screen.")
    }
    return fastestScreen
  }
}

extension Display {
  /// The number of frames issued per second.
  public var frameRate: Int {
    screen.maximumFramesPerSecond
  }
  
  /// The resolution of the rendering region, according to the operating
  /// system's scale factor.
  public var windowSize: Int {
    var output = Double(renderTargetSize)
    output /= screen.backingScaleFactor
    
    guard output == floor(output) else {
      fatalError("Resolution was not evenly divisible by scaling factor.")
    }
    return Int(output)
  }
}
