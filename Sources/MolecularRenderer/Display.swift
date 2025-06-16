#if os(macOS)
import AppKit
#else
import SwiftCOM
import WinSDK
#endif

// IDXGIAdapter -> IDXGIOutput -> GetDesc -> HMONITOR
// A system have multiple adapters, each of which maps to a 'Device'. A
// device has multiple outputs, each of which maps to a 'Display'. Modify the
// existing utilities so that '.fastestScreenID' belongs to an instance of
// 'Device', not the 'Display' type object. This creates an inevitable
// inconsistency between the appearance of the two APIs for "fastest" IDs.
//
// For window dimensions, use HMONITOR -> GetMonitorInfo -> rcWork
// Use rcWork for consistency with macOS, which centers the window in the
// "work area" of the screen.
//
// For device name, there are two paths:
// GetDesc -> DeviceName -> convert WCHAR to CHAR
// HMONITOR -> GetMonitorInfo -> MONITORINFOEXA -> szDevice
// The first seems easiest.
//
// For refresh rate, there are two paths:
// IDXGIOutput -> GetDisplayModeList -> filter based on resolution -> Refresh...
// device name -> EnumDisplaySettings -> iModeNum = UInt32.max -> dmDisplayFr...
// The latter seems more appropriate because it reflects the system's current
// refresh rate.

public struct DisplayDescriptor {
  /// The graphics device to which monitors are connected.
  public var device: Device?
  
  /// The actual size of the window (in pixels) on the screen.
  public var frameBufferSize: SIMD2<Int>?
  
  /// The identifier for the monitor.
  public var monitorID: Int?
  
  public init() {
    
  }
}

public class Display {
  // The resolution of the rendering region, in pixels.
  let frameBufferSize: SIMD2<Int>
  
  #if os(macOS)
  let nsScreen: NSScreen
  #else
  let dxgiOutput: SwiftCOM.IDXGIOutput
  #endif
  
  public init(descriptor: DisplayDescriptor) {
    // Check the properties whose necessity depends on the platform. On Mac,
    // the user-facing API requires that you specify the device, for consistency
    // across platforms.
    #if os(macOS)
    guard descriptor.device != nil else {
      fatalError("Descriptor was incomplete.")
    }
    #else
    guard let device = descriptor.device else {
      fatalError("Descriptor was incomplete.")
    }
    #endif
    
    // Check the other properties.
    guard let frameBufferSize = descriptor.frameBufferSize,
          let monitorID = descriptor.monitorID else {
      fatalError("Descriptor was incomplete.")
    }
    self.frameBufferSize = frameBufferSize
    
    // Materialize the NSScreen (macOS).
    #if os(macOS)
    var matchedScreen: NSScreen?
    for screen in NSScreen.screens {
      let candidateMonitorID = Display.number(screen: screen)
      if monitorID == candidateMonitorID {
        matchedScreen = screen
        break
      }
    }
    guard let matchedScreen else {
      fatalError("Could not find the screen.")
    }
    self.nsScreen = matchedScreen
    #endif
    
    // Materialize the IDXGIOutput (Windows).
    #if os(Windows)
    // select device.outputs[screenID]
    //
    // This might be an isolable stepping stone before working on the other
    // sub-goals of the Display API. Just explicitly specify screenID = 0
    // throughout the process.
    let outputs = device.outputs
    guard monitorID >= 0,
          monitorID < outputs.count else {
      fatalError("Monitor ID was out of range.")
    }
    self.dxgiOutput = outputs[monitorID]
    
    print(Display.deviceName(output: dxgiOutput))
    #endif
  }
}

extension Device {
  #if os(Windows)
  var outputs: [SwiftCOM.IDXGIOutput] {
    var dxgiOutputs: [SwiftCOM.IDXGIOutput] = []
    
    var outputID: UInt32 = .zero
    while true {
      let dxgiOutput = try? dxgiAdapter.EnumOutputs(outputID)
      if let dxgiOutput {
        dxgiOutputs.append(dxgiOutput)
        outputID += 1
      } else {
        break
      }
    }
    return dxgiOutputs
  }
  #endif
  
  /// The identifier for the monitor with the highest refresh rate.
  public var fastestMonitorID: Int {
    // Prefer the monitor with the highest frame rate. If there's a tie,
    // choose the monitor that appears first in the list. It's probably the
    // primary monitor.
    
    #if os(macOS)
    var fastestScreen: NSScreen?
    var fastestFrameRate: Int = .zero
    for screen in NSScreen.screens {
      let candidateFrameRate = screen.maximumFramesPerSecond
      if candidateFrameRate > fastestFrameRate {
        fastestScreen = screen
        fastestFrameRate = candidateFrameRate
      }
    }
    
    guard let fastestScreen else {
      fatalError("Failed to find fastest screen.")
    }
    return Display.number(screen: fastestScreen)
    #else
    fatalError("Not implemented.")
    #endif
  }
}

extension Display {
  #if os(macOS)
  static func number(screen: NSScreen) -> Int {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    let screenNumberAny = screen.deviceDescription[key]!
    let screenNumberNSNumber = screenNumberAny as! NSNumber
    let screenNumber = screenNumberNSNumber.uint32Value
    return Int(screenNumber)
  }
  #endif
  
  /// The number of frames issued per second.
  public var frameRate: Int {
    #if os(macOS)
    nsScreen.maximumFramesPerSecond
    #else
    fatalError("Not implemented.")
    #endif
  }
  
  #if os(macOS)
  // The resolution of the rendering region, according to the operating
  // system's scale factor.
  var windowSize: SIMD2<Int> {
    var output = SIMD2<Double>(frameBufferSize)
    output /= nsScreen.backingScaleFactor
    
    guard output == output.rounded(.down) else {
      fatalError("Resolution was not evenly divisible by scaling factor.")
    }
    return SIMD2<Int>(output)
  }
  #endif
  
  #if os(Windows)
  static func deviceName(output: SwiftCOM.IDXGIOutput) -> String {
    let descriptor = try! output.GetDesc()
    
    return withUnsafePointer(to: descriptor.DeviceName) { tuplePointer in
      let rawPointer = UnsafeRawPointer(tuplePointer)
      let wcharPointer = rawPointer.assumingMemoryBound(to: UInt16.self)
      
      // DXGI_OUTPUT_DESC has a C-style array with 32 members.
      var ccharPointer: [UInt8] = []
      for characterID in 0..<32 {
        let wchar = wcharPointer[characterID]
        let cchar = UInt8(wchar)
        ccharPointer.append(cchar)
      }
      
      return String(decoding: ccharPointer, as: UTF8.self)
    }
  }
  
  static func frameRate(deviceName: String) -> Int {
    fatalError("TODO")
  }
  #endif
  
  // Cross-platform function
  // static func workArea(screen: NSScreen) -> SIMD4<Int>
  // static func monitor(output: SwiftCOM.IDXGIOutput) -> HMONITOR
  // static func workArea(monitor: HMONITOR) -> SIMD4<Int>
}
