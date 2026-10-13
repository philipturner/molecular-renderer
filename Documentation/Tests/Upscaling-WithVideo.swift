import Foundation
import GIFModule
import HDL
import MolecularRenderer
import QuaternionModule

// MARK: - GIF Recording Setup
let renderingOffline: Bool = true
let frameCount: Int = 60 * 10  // 10 seconds at 60 FPS
let gifFrameSkipRate: Int = 3  // Save every 3rd frame for 20 FPS GIF

let gifWidth = renderingOffline ? 1440 : 1440 * 3
let gifHeight = renderingOffline ? 1080 : 1080 * 3

var gif = GIF(
  width: gifWidth,
  height: gifHeight,
  loopCount: 0)
var gifImage = GIFModule.Image(width: gifWidth, height: gifHeight)

// Global time tracking for offline rendering
var currentTime: Float = 0

@MainActor
func createApplication() -> Application {
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)

  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  if renderingOffline {
    displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
  } else {
    displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
    displayDesc.monitorID = device.fastestMonitorID
  }
  let display = Display(descriptor: displayDesc)

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
    return currentTime
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

// MARK: - Main Loop

if !renderingOffline {
  print("Recording molecular upscaling animation - will save as GIF...")
  application.run {
    modifyAtoms()
    modifyCamera()

    let frameID = application.frameID

    // Render and save frames for GIF every few frames
    if frameID % gifFrameSkipRate == 0 && frameID > 0 {
      var image = application.render()
      image = application.upscale(image: image)

      // Convert to GIF format
      for y in 0..<gifImage.height {
        for x in 0..<gifImage.width {
          let pixelIndex = y * gifImage.width + x
          let pixel = image.pixels[pixelIndex]

          let r = UInt8(max(0, min(255, Float(pixel.x) * 255)))
          let g = UInt8(max(0, min(255, Float(pixel.y) * 255)))
          let b = UInt8(max(0, min(255, Float(pixel.z) * 255)))

          let color = Color(red: r, green: g, blue: b)
          gifImage[y, x] = color
        }
      }

      let frame = Frame(
        image: gifImage,
        delayTime: 5, // 20 FPS
        localQuantization: OctreeQuantization(fromImage: gifImage)
      )
      gif.frames.append(frame)

      let progress = frameID / gifFrameSkipRate
      let total = frameCount / gifFrameSkipRate
      print("Recorded frame \(progress) / \(total)")
    }

    var image = application.render()
    image = application.upscale(image: image)
    application.present(image: image)

    // Exit after recording all frames
    if frameID >= frameCount {
      print("Encoding GIF...")
      let data = try! gif.encoded()
      let filePath = "Art/molecular-upscaling-animation.gif"
      let succeeded = FileManager.default.createFile(
        atPath: filePath,
        contents: data
      )
      if succeeded {
        print("Saved GIF to \(filePath)")
      } else {
        print("Failed to save GIF")
      }
      exit(0)
    }
  }
} else {
  print("Recording molecular upscaling animation offline - will save as GIF...")

  for frameID in 1...frameCount {
    // Update time for this frame (60 FPS)
    currentTime = Float(frameID) / 60.0

    modifyAtoms()
    modifyCamera()

    // Render and save frames for GIF every few frames
    if frameID % gifFrameSkipRate == 0 {
      var image = application.render()
      if !renderingOffline {
        image = application.upscale(image: image)
      }

      // Convert to GIF format
      for y in 0..<gifImage.height {
        for x in 0..<gifImage.width {
          let pixelIndex = y * gifImage.width + x
          let pixel = image.pixels[pixelIndex]

          let r = UInt8(max(0, min(255, Float(pixel.x) * 255)))
          let g = UInt8(max(0, min(255, Float(pixel.y) * 255)))
          let b = UInt8(max(0, min(255, Float(pixel.z) * 255)))

          let color = Color(red: r, green: g, blue: b)
          gifImage[y, x] = color
        }
      }

      let frame = Frame(
        image: gifImage,
        delayTime: 5, // 20 FPS
        localQuantization: OctreeQuantization(fromImage: gifImage)
      )
      gif.frames.append(frame)

      let progress = frameID / gifFrameSkipRate
      let total = frameCount / gifFrameSkipRate
      print("Recorded frame \(progress) / \(total)")
    }
  }

  print("Encoding GIF...")
  let data = try! gif.encoded()
  let filePath = "Art/molecular-upscaling-animation.gif"
  let succeeded = FileManager.default.createFile(
    atPath: filePath,
    contents: data
  )
  if succeeded {
    print("Saved GIF to \(filePath)")
  } else {
    print("Failed to save GIF")
  }
}