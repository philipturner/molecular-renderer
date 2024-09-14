import AppKit

public struct DisplayDescriptor {
  public var renderTargetSize: Int?
  public var screenNumber: UInt32?
  
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
          let screenNumber = descriptor.screenNumber else {
      fatalError("Descriptor was incomplete.")
    }
    self.renderTargetSize = renderTargetSize
    self.screen = Display.findScreen(screenNumber: screenNumber)
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
  
  public static func findScreen(screenNumber: UInt32) -> NSScreen {
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
