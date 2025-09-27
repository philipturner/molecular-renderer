// Tasks:
// - Eventual ergonomic API should accept an angle in radians instead of
//   degrees, with a simpler name than "fov***InDegrees".
//   'cameraFovAngleVertical', copied from the AMD FidelityFX API, is a great
//   idea.
// - Extract the hard-coded camera logic into ::primaryRayDirection and a
//   CPU-side API.
// - Create an animation where the molecules are still, but the camera rotates
//   to go above them and flip back around to the starting point, in a loop.
//   - 0.5 Hz rotation rate, just like the previous animation where atoms moved.
//
// Implementation of upscaling:
// - Start with a simple kernel that just copies the center pixel 2-3x to the
//   final pixel (nearest neighbor sampling).
// - Make the upscaling process optional to enable/disable. For example,
//   'ApplicationDescriptor.upscaleFactor' with a default of Float(3). If the
//   value is instead 1, an error will occur when the user calls
//   'Application.upscale(image:)'. Conversely, when it is more than 1, an
//   error will occur when this function is not called.
// - Only accepting integers for the upscale factor at the moment, although the
//   appropriate data type is a floating-point number.
// - Debug motion vectors and camera orientation matrices changing between
//   frames. Also establish depth textures; all the details except actual
//   invocation of the upscaler.
// - Implement Apple MetalFX upscaling first, because more familiar (have
//   correctly working reference code).

import HDL
import MolecularRenderer
import QuaternionModule

#if os(Windows)
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
  let time = createTime()
  
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
      let atom = isopropanol[i]
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
      let atom = silane[i]
      application.atoms[atomID] = atom
    }
  }
}

// Enter the run loop.
application.run {
  modifyAtoms()
  let image = application.render()
  application.present(image: image)
}
