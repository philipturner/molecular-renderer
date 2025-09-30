// Implementation of upscaling:
// - Massively clean up the old 'FFXUpscaler' as 'FFXContext'.
// - Implement jitter offsets.
//   - Fetch the official offsets from the FidelityFX API on Windows.
//   - Write custom code to generate the same sequence of offsets on macOS.

import HDL
import MolecularRenderer
import QuaternionModule

#if os(Windows)
import FidelityFX
import SwiftCOM
import WinSDK
#endif

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  #if os(macOS)
  displayDesc.frameBufferSize = SIMD2<Int>(1920, 1440)
  #else
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
  #endif
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.allocationSize = 1_000_000
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 2
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

// State variable to facilitate atom transactions for the animation.
enum AnimationState {
  case isopropanol
  case silane
}
var animationState: AnimationState?

func createIsopropanol() -> [SIMD4<Float>] {
  return [
    Atom(position: SIMD3( 2.0186, -0.2175,  0.7985) * 0.1, element: .hydrogen),
    Atom(position: SIMD3( 1.4201, -0.2502, -0.1210) * 0.1, element: .carbon),
    Atom(position: SIMD3( 1.6783,  0.6389, -0.7114) * 0.1, element: .hydrogen),
    Atom(position: SIMD3( 1.7345, -1.1325, -0.6927) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-0.0726, -0.3145,  0.1833) * 0.1, element: .carbon),
    Atom(position: SIMD3(-0.2926, -1.2317,  0.7838) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-0.3758,  0.8195,  0.9774) * 0.1, element: .oxygen),
    Atom(position: SIMD3(-1.3159,  0.8236,  1.0972) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-0.8901, -0.3435, -1.1071) * 0.1, element: .carbon),
    Atom(position: SIMD3(-0.7278,  0.5578, -1.7131) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-0.6126, -1.2088, -1.7220) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-1.9673, -0.4150, -0.9062) * 0.1, element: .hydrogen),
  ]
}

func createSilane() -> [SIMD4<Float>] {
  return [
    Atom(position: SIMD3( 0.0000,  0.0000,  0.0000) * 0.1, element: .silicon),
    Atom(position: SIMD3( 0.8544,  0.8544,  0.8544) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-0.8544, -0.8544,  0.8544) * 0.1, element: .hydrogen),
    Atom(position: SIMD3(-0.8544,  0.8544, -0.8544) * 0.1, element: .hydrogen),
    Atom(position: SIMD3( 0.8544, -0.8544, -0.8544) * 0.1, element: .hydrogen),
  ]
}

@MainActor
func createTime() -> Float {
  let elapsedFrames = application.clock.frames
  let frameRate = application.display.frameRate
  let seconds = Float(elapsedFrames) / Float(frameRate)
  return seconds
}

@MainActor
func modifyAtoms() {
  // 0.5 Hz rotation rate
  let time = createTime()
  let angleDegrees = 0.5 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(0, 1, 0))
  
  let roundedDownTime = Int(time.rounded(.down))
  if roundedDownTime % 2 == 0 {
    let isopropanol = createIsopropanol()
    if animationState == .silane {
      for atomID in 12..<17 {
        application.atoms[atomID] = nil
      }
    }
    
    animationState = .isopropanol
    for i in isopropanol.indices {
      let atomID = 0 + i
      var atom = isopropanol[i]
      atom.position = rotation.act(on: atom.position)
      application.atoms[atomID] = atom
    }
  } else {
    let silane = createSilane()
    if animationState == .isopropanol {
      for atomID in 0..<12 {
        application.atoms[atomID] = nil
      }
    }
    
    animationState = .silane
    for i in silane.indices {
      let atomID = 12 + i
      var atom = silane[i]
      atom.position = rotation.act(on: atom.position)
      application.atoms[atomID] = atom
    }
  }
}

@MainActor
func modifyCamera() {
  // Place the camera 1.0 nm away from the origin.
  application.camera.position = SIMD3(0, 0, 1.00)
  
  application.camera.basis.0 = SIMD3(1, 0, 0)
  application.camera.basis.1 = SIMD3(0, 1, 0)
  application.camera.basis.2 = SIMD3(0, 0, 1)
  application.camera.fovAngleVertical = Float.pi / 180 * 40
}

#if os(Windows)
do {
  var ffxContextDesc = FFXContextDescriptor()
  ffxContextDesc.device = application.device
  ffxContextDesc.display = application.display
  ffxContextDesc.upscaleFactor = 2
  let ffxContext = FFXContext(descriptor: ffxContextDesc)
  
  func halton(index: Int, base: Int) -> Float {
    var result: Float = 0.0
    var fractional: Float = 1.0
    var currentIndex: Int = index
    while currentIndex > 0 {
      fractional /= Float(base)
      result += fractional * Float(currentIndex % base)
      currentIndex /= base
    }
    return result
  }
  
  func createJitterOffset(index: Int) -> SIMD2<Float> {
    // The sample uses a Halton sequence rather than purely random numbers to
    // generate the sample positions to ensure good pixel coverage. This has the
    // result of sampling a different point within each pixel every frame.
    
    // Return Halton samples (+/- 0.5, +/- 0.5) that represent offsets of up to
    // half a pixel.
    let x = halton(index: index + 1, base: 2) - 0.5
    let y = halton(index: index + 1, base: 3) - 0.5
    
    // We're not sampling textures or working with multiple coordinate spaces.
    // No need to flip the Y coordinate to match another coordinate space.
    return SIMD2(x, y)
  }
  
  for index in 0..<72 {
    do {
      let jitterOffset = createJitterOffset(index: index)
      print(jitterOffset[0], jitterOffset[1], terminator: " | ")
    }
    
    do {
      let jitterOffset = FFXDescriptor<ffxQueryDescUpscaleGetJitterOffset>()
      jitterOffset.type = FFX_API_QUERY_DESC_TYPE_UPSCALE_GETJITTEROFFSET
      jitterOffset.value.index = Int32(index)
      jitterOffset.value.phaseCount = 72
      
      var pOut: UnsafeMutablePointer<Float> = .allocate(capacity: 2)
      defer { pOut.deallocate() }
      pOut[0] = 5
      pOut[1] = 5
      jitterOffset.value.pOutX = pOut
      jitterOffset.value.pOutY = pOut + 1
      
      FFXContext.query(descriptor: jitterOffset)
      print(pOut[0], pOut[1], terminator: " | ")
    }
    
    if index < 32 {
      let jitterOffset = FFXDescriptor<ffxQueryDescUpscaleGetJitterOffset>()
      jitterOffset.type = FFX_API_QUERY_DESC_TYPE_UPSCALE_GETJITTEROFFSET
      jitterOffset.value.index = Int32(index)
      jitterOffset.value.phaseCount = 32
      
      var pOut: UnsafeMutablePointer<Float> = .allocate(capacity: 2)
      defer { pOut.deallocate() }
      pOut[0] = 5
      pOut[1] = 5
      jitterOffset.value.pOutX = pOut
      jitterOffset.value.pOutY = pOut + 1
      
      FFXContext.query(descriptor: jitterOffset)
      print(pOut[0], pOut[1], terminator: "")
    }
    
    print()
  }
}
#endif

// Enter the run loop.
application.run {
  modifyAtoms()
  modifyCamera()
  
  let intermediate = application.render()
  let upscaled = application.upscale(image: intermediate)
  application.present(image: upscaled)
}
