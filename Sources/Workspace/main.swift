// Implementation of upscaling:
// - Query the memory usage of a FidelityFX upscaler prior to creating it,
//   for both 2x and 3x upscaling.
// - Find the cause of the segmentation fault when doing the above task!
// - Make a Swift utility that reduces the boilerplate for creating FidelityFX
//   API descriptors, managing their headers, managing their deallocation.
//   - '_read' and '_modify' to elevate a data structure stored deep inside
//     (privately) instead of a public stored property.
// - Massively clean up the old 'FFXUpscaler' as 'FFXContext'.
// - Implement jitter offsets.
//   - Fetch the official offsets from the FidelityFX API on Windows.
//   - Challenging open-ended question of where to put the code that invokes
//     FidelityFX, during this first step.
//   - Write custom code to generate the same sequence of offsets on macOS.
// - Implement Apple MetalFX upscaling first, because more familiar (have
//   correctly working reference code).

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
  applicationDesc.upscaleFactor = 3
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
print("checkpoint -1")
do {
  // Allocate the UpscaleGetGPUMemoryUsageV2, causing a memory leak.
  let upscaleGetGPUMemoryUsageV2 = UnsafeMutablePointer<ffxQueryDescUpscaleGetGPUMemoryUsageV2>.allocate(capacity: 1)
  upscaleGetGPUMemoryUsageV2.pointee.header.type = UInt64(FFX_API_QUERY_DESC_TYPE_UPSCALE_GPU_MEMORY_USAGE_V2)
  upscaleGetGPUMemoryUsageV2.pointee.header.pNext = nil
  print("checkpoint 0")
  
  // Bind the device, causing a memory leak.
  do {
    let iid = SwiftCOM.ID3D12Device.IID
    let d3d12Device = application.device.d3d12Device
    let interface = try! d3d12Device.QueryInterface(iid: iid)
    guard let interface else {
      fatalError("Could not get interface.")
    }
    upscaleGetGPUMemoryUsageV2.pointee.device = interface
  }
  print("checkpoint 1")
  
  // Bind the texture dimensions.
  func createFFXDimensions(
    _ input: SIMD2<Int>
  ) -> FfxApiDimensions2D {
    var output = FfxApiDimensions2D()
    output.width = UInt32(input[0])
    output.height = UInt32(input[1])
    return output
  }
  do {
    let maxRenderSize = createFFXDimensions(
      application.display.frameBufferSize / 3)
    let maxUpscaleSize = createFFXDimensions(
      application.display.frameBufferSize)
    upscaleGetGPUMemoryUsageV2.pointee.maxRenderSize = maxRenderSize
    upscaleGetGPUMemoryUsageV2.pointee.maxUpscaleSize = maxUpscaleSize
  }
  print("checkpoint 2")
  
  upscaleGetGPUMemoryUsageV2.pointee.flags = UInt32(
    FFX_UPSCALE_ENABLE_DEPTH_INVERTED.rawValue)
  print("checkpoint 3")
  
  // Allocate the EffectMemoryUsage, causing a memory leak.
  var effectMemoryUsage = UnsafeMutablePointer<FfxApiEffectMemoryUsage>.allocate(capacity: 1)
  upscaleGetGPUMemoryUsageV2.pointee.gpuMemoryUsageUpscaler = effectMemoryUsage
  print("checkpoint 4")
  
  // Obtain a pointer to the header.
  upscaleGetGPUMemoryUsageV2.withMemoryRebound(
    to: ffxApiHeader.self, capacity: 1
  ) { pointer in
    print("checkpoint 4.1")
    let error = ffxQuery(nil, pointer)
    print("checkpoint 4.2")
    guard error == 0 else {
      fatalError("Received error code \(error).")
    }
  }
  print("checkpoint 5")
  
  // 50% of the time, this crashes with a segmentation fault.
  //
  // 1440x1080, 2x upscaling
  //   totalUsageInBytes 48_758_784
  //   aliasableUsageInBytes 5_636_096
  //
  // 1440x1080, 3x upscaling
  //   totalUsageInBytes 36_896_768
  //   aliasableUsageInBytes 3_407_872
  
  print("Default Upscaler Query GPUMemoryUsageV2 totalUsageInBytes", effectMemoryUsage.pointee.totalUsageInBytes)
  print("Default Upscaler Query GPUMemoryUsageV2 aliasableUsageInBytes", effectMemoryUsage.pointee.aliasableUsageInBytes)
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
