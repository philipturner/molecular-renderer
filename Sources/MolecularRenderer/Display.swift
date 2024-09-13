import AppKit

public struct DisplayDescriptor {
  public var renderTargetSize: Int?
  public var screenNumber: UInt32?
  
  public init() {
    
  }
}

public class Display {
  private var _screen: NSScreen
  private var _renderTargetSize: Int
  
  public init(descriptor: DisplayDescriptor) {
    guard let renderTargetSize = descriptor.renderTargetSize else {
      fatalError("Descriptor was incomplete.")
    }
    _renderTargetSize = renderTargetSize
    
    if let screenNumber = descriptor.screenNumber {
      _screen = Display.findScreen(screenNumber: screenNumber)
    } else {
      _screen = Display.findFastestScreen()
    }
  }
}

extension Display {
  public static func screenNumber(screen: NSScreen) -> UInt32 {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    let screenNumberAny = screen.deviceDescription[key]!
    let screenNumberNSNumber = screenNumberAny as! NSNumber
    let screenNumber = screenNumberNSNumber.uint32Value
    return screenNumber
  }
  
  static func findScreen(screenNumber: UInt32) -> NSScreen {
    let screens = NSScreen.screens
    
    var matchedScreen: NSScreen?
    for screen in screens {
      let candidateScreenNumber = Display.screenNumber(screen: screen)
      if screenNumber == candidateScreenNumber {
        matchedScreen = screen
      }
    }
    
    guard let matchedScreen else {
      fatalError("Failed to find screen matching number: \(screenNumber)")
    }
    return matchedScreen
  }
  
  static func findFastestScreen() -> NSScreen {
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
    _screen.maximumFramesPerSecond
  }
  
  /// The resolution of the rendering region, in pixels.
  public var renderTargetSize: Int {
    _renderTargetSize
  }
  
  /// The display chosen for rendering at program startup.
  public var screen: NSScreen {
    _screen
  }
  
  /// The resolution of the rendering region, according to the operating
  /// system's scale factor.
  public var windowSize: Int {
    var output = Double(_renderTargetSize)
    output /= _screen.backingScaleFactor
    
    guard output == floor(output) else {
      fatalError("Resolution was not evenly divisible by scaling factor.")
    }
    return Int(output)
  }
}
