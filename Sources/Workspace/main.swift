import Foundation
import GIF
import HDL
import MolecularRenderer
import QuaternionModule

let renderingOffline: Bool = true

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
  if !renderingOffline {
    displayDesc.monitorID = device.fastestMonitorID
  }
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  if renderingOffline {
    applicationDesc.upscaleFactor = 1
  } else {
    applicationDesc.upscaleFactor = 3
  }
  
  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = 64
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
  if renderingOffline {
    let elapsedFrames = application.frameID
    let frameRate: Int = 60
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  } else {
    let elapsedFrames = application.clock.frames
    let frameRate = application.display.frameRate
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  }
}

@MainActor
func modifyAtoms() {
  // 0.5 Hz rotation rate
  let time = createTime()
  let angleDegrees = 0.5 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(0, 1, 0))
  
  let roundedDownTime = Int((time / 3).rounded(.down))
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
  // 0.1 Hz rotation rate
  let time = createTime()
  let angleDegrees = 0.1 * time * 360
  let rotation = Quaternion<Float>(
    angle: Float.pi / 180 * angleDegrees,
    axis: SIMD3(-1, 0, 0))
  
  // Place the camera 1.0 nm away from the origin.
  application.camera.position = rotation.act(on: SIMD3(0, 0, 1.00))
  
  application.camera.basis.0 = rotation.act(on: SIMD3(1, 0, 0))
  application.camera.basis.1 = rotation.act(on: SIMD3(0, 1, 0))
  application.camera.basis.2 = rotation.act(on: SIMD3(0, 0, 1))
  application.camera.fovAngleVertical = Float.pi / 180 * 40
}

// Enter the run loop.
if !renderingOffline {
  application.run {
    modifyAtoms()
    modifyCamera()
    
    var image = application.render()
    image = application.upscale(image: image)
    application.present(image: image)
  }
} else {
  let frameBufferSize = application.display.frameBufferSize
  var gif = GIF(
    width: frameBufferSize[0],
    height: frameBufferSize[1])
  
  // Overall latency summary for offline mode:
  //
  // throughput @ 1440x1080, 60 FPS
  // macOS: 22.8 minutes / minute of content
  // Windows: 46.6 minutes / minute of content
  //
  // Costs are probably agnostic to level of detail in the scene. On macOS, the
  // encoding latency was identical for an accidentally 100% black image.
  print("rendering frames")
  for _ in 0..<10 {
    
    modifyAtoms()
    modifyCamera()
    
    // GPU-side bottleneck
    // throughput @ 1440x1080, 64 AO samples
    // macOS: 14-18 ms/frame
    // Windows: 50-70 ms/frame
    let image = application.render()
    
    // single-threaded bottleneck
    // throughput @ 1440x1080
    // macOS: 5 ms/frame
    // Windows: 262 ms/frame (possibly from lack of native FP16 instructions)
    //
    // Could probably change the Molecular Renderer API to convert to 8-bit
    // integers on the GPU side. But that adds complexity to the implementation
    // and this is probably not an issue on newer CPUs with better ISAs.
    let loopStartCheckpoint = Date()
    let cairoImage = CairoImage(
      width: frameBufferSize[0],
      height: frameBufferSize[1])
    for y in 0..<frameBufferSize[1] {
      for x in 0..<frameBufferSize[0] {
        let address = y * frameBufferSize[0] + x
        
        // Leaving this in the original SIMD4<Float16> makes the entire
        // loop 1.5x slower on Windows. Better to cast to SIMD4<Float>.
        let pixel = SIMD4<Float16>(image.pixels[address])
        
        // Don't clamp to [0, 255] range to avoid a minor CPU-side bottleneck.
        // It theoretically should never go outside this range; we just lose
        // the ability to assert this.
        let scaled = pixel * 255
        let rounded = scaled.rounded(.toNearestOrEven)
        
        let rounded1 = scaled.rounded(.toNearestOrEven)
        let rounded2 = (scaled + 0.5).rounded(.down)
        if any(rounded1 .!= rounded2) {
          fatalError("We have a problem: \(255 * SIMD4<Float>(image.pixels[address])) \(scaled) \(rounded1) \(rounded2).")
        }
        
        // Avoid massive CPU-side bottleneck for unknown reason when casting
        // floating point vector to integer vector.
        let r = UInt8(rounded2[0])
        let g = UInt8(rounded2[1])
        let b = UInt8(rounded2[2])
        let a = UInt8(rounded2[3])
        
        // rgba
        let rgbaVector = SIMD4<UInt8>(r, g, b, a)
        
        // bgra
        let bgraVector = SIMD4<UInt8>(
          rgbaVector[2],
          rgbaVector[1],
          rgbaVector[0],
          rgbaVector[3])
        
        // bgra big-endian
        // argb little-endian
        let bgraScalar = unsafeBitCast(bgraVector, to: UInt32.self)
        let color = Color(argb: bgraScalar)
        cairoImage[y, x] = color
      }
    }
    let loopEndCheckpoint = Date()
    print(loopEndCheckpoint.timeIntervalSince(loopStartCheckpoint))
    
    // single-threaded bottleneck
    // throughput @ 1440x1080
    // macOS: 76 ms/frame
    // Windows: 271 ms/frame
    //
    // Could probably parallelize this part to improve performance on the
    // Windows machine.
    let quantization = OctreeQuantization(fromImage: cairoImage)
    
    let frame = Frame(
      image: cairoImage,
      delayTime: 5, // 20 FPS
      localQuantization: quantization)
    gif.frames.append(frame)
    
    
  }
  
  // multi-threaded bottleneck
  // throughput @ 1440x1080
  // macOS: 252 ms/frame
  // Windows: 174 ms/frame (abnormally fast compared to macOS)
  print("encoding GIF")
  let encodeStartCheckpoint = Date()
  let data = try! gif.encoded()
  let encodeEndCheckpoint = Date()
  
  let encodedSizeRepr = String(format: "%.1f", Float(data.count) / 1e6)
  print("encoded size:", encodedSizeRepr, "MB")
  print(encodeEndCheckpoint.timeIntervalSince(encodeStartCheckpoint))
  
  // SSD access bottleneck
  //
  // latency @ 1440x1080, 10 frames, 2.1 MB
  // macOS: 1.6 ms
  // Windows: 16.3 ms
  //
  // latency @ 1440x1080, 60 frames, 12.4 MB
  // macOS: 4.1 ms
  // Windows: 57.7 ms
  //
  // Order of magnitude, 1 minute of video is 1 GB of GIF.
  let packagePath = FileManager.default.currentDirectoryPath
  let filePath = "\(packagePath)/.build/video.gif"
  let succeeded = FileManager.default.createFile(
    atPath: filePath,
    contents: data)
  guard succeeded else {
    fatalError("Could not write to file.")
  }
}
