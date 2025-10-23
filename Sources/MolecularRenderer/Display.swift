#if os(macOS)
import AppKit
#else
import SwiftCOM
import WinSDK
#endif

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
  /// The resolution of the rendering region, in pixels.
  public let frameBufferSize: SIMD2<Int>
  
  let isOffline: Bool
  #if os(macOS)
  var nsScreen: NSScreen?
  #else
  var dxgiOutput: SwiftCOM.IDXGIOutput?
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
    guard let frameBufferSize = descriptor.frameBufferSize else {
      fatalError("Descriptor was incomplete.")
    }
    self.frameBufferSize = frameBufferSize
    
    if let monitorID = descriptor.monitorID {
      self.isOffline = false
      
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
      let outputs = device.outputs
      guard monitorID >= 0,
            monitorID < outputs.count else {
        fatalError("Monitor ID was out of range.")
      }
      self.dxgiOutput = outputs[monitorID]
      #endif
    } else {
      self.isOffline = true
    }
  }
  
  /// The number of frames issued per second.
  public var frameRate: Int {
    if isOffline {
      return 0
    } else {
      #if os(macOS)
      return nsScreen!.maximumFramesPerSecond
      #else
      let deviceName = Display.deviceName(output: dxgiOutput!)
      return Display.frameRate(deviceName: deviceName)
      #endif
    }
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
    let outputs = self.outputs
    
    var fastestMonitorID: Int?
    var fastestFrameRate: Int = .zero
    for outputID in outputs.indices {
      let output = outputs[outputID]
      
      let deviceName = Display.deviceName(output: output)
      let candidateFrameRate = Display.frameRate(deviceName: deviceName)
      if candidateFrameRate > fastestFrameRate {
        fastestMonitorID = outputID
        fastestFrameRate = candidateFrameRate
      }
    }
    
    guard let fastestMonitorID else {
      fatalError("Failed to find fastest monitor ID.")
    }
    return fastestMonitorID
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
  
  #if os(macOS)
  // The resolution of the rendering region, according to the operating
  // system's scale factor.
  var contentSize: SIMD2<Double> {
    var output = SIMD2<Double>(frameBufferSize)
    output /= nsScreen.backingScaleFactor
    return output
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
    // Bypass a compiler error.
    let ENUM_CURRENT_SETTINGS = UInt32(bitPattern: -1)
    
    var devMode = DEVMODEA()
    devMode.dmSize = UInt16(MemoryLayout<DEVMODEA>.size)
    let succeeded = EnumDisplaySettingsA(
      deviceName, // lpszDeviceName
      ENUM_CURRENT_SETTINGS, // iModeNum
      &devMode) // lpDevMode
    guard succeeded else {
      fatalError("Could not retrieve display settings.")
    }
    
    return Int(devMode.dmDisplayFrequency)
  }
  #endif
  
  #if os(Windows)
  static func monitor(output: SwiftCOM.IDXGIOutput) -> HMONITOR {
    let descriptor = try! output.GetDesc()
    guard let monitor = descriptor.Monitor else {
      fatalError("Could not get monitor.")
    }
    return monitor
  }
  
  // The coordinates of the work area, in pixels.
  static func workArea(monitor: HMONITOR) -> SIMD4<Int> {
    var monitorInfo = MONITORINFO()
    monitorInfo.cbSize = UInt32(MemoryLayout<MONITORINFO>.size)
    
    SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
    let succeeded = GetMonitorInfoA(
      monitor, // hMonitor
      &monitorInfo) // lpmi
    guard succeeded else {
      fatalError("Could not retrieve monitor info.")
    }
    
    let rcWork = monitorInfo.rcWork
    return SIMD4(
      Int(rcWork.left),
      Int(rcWork.top),
      Int(rcWork.right),
      Int(rcWork.bottom))
  }
  #endif
}
