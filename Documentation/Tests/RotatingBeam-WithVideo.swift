import Foundation
import GIFModule
import HDL
import MolecularRenderer
import QuaternionModule

// MARK: - User-Facing Options

// 16 is reproducer for a bug, originally 10.
let beamDepth: Int = 16

// MARK: - GIF Recording Setup
let renderingOffline: Bool = true
let frameCount: Int = 60 * 5  // 5 seconds at 60 FPS
let gifFrameSkipRate: Int = 3  // Save every 3rd frame for 20 FPS GIF

let gifWidth = renderingOffline ? 1080 : 1080 * 3
let gifHeight = renderingOffline ? 1080 : 1080 * 3

var gif = GIF(
  width: gifWidth,
  height: gifHeight,
  loopCount: 0)
var gifImage = GIFModule.Image(width: gifWidth, height: gifHeight)

// Global time tracking for offline rendering
var currentTime: Float = 0

// MARK: - Compile Structures

let crossThickness: Int = 16
let crossSize: Int = 120
let actualWorldDimension: Float = 96
let paddedWorldDimension: Float = 128

func passivate(topology: inout Topology) {
  func createHydrogen(
    atomID: UInt32,
    orbital: SIMD3<Float>
  ) -> Atom {
    let atom = topology.atoms[Int(atomID)]

    var bondLength = atom.element.covalentRadius
    bondLength += Element.hydrogen.covalentRadius

    let position = atom.position + bondLength * orbital
    return Atom(position: position, element: .hydrogen)
  }

  let orbitalLists = topology.nonbondingOrbitals()

  var insertedAtoms: [Atom] = []
  var insertedBonds: [SIMD2<UInt32>] = []
  for atomID in topology.atoms.indices {
    let orbitalList = orbitalLists[atomID]
    for orbital in orbitalList {
      let hydrogen = createHydrogen(
        atomID: UInt32(atomID),
        orbital: orbital)
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(hydrogen)

      let bond = SIMD2(
        UInt32(atomID),
        UInt32(hydrogenID))
      insertedBonds.append(bond)
    }
  }
  topology.atoms += insertedAtoms
  topology.bonds += insertedBonds
}

func createCross() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds {
      Float(crossSize) * h +
      Float(crossSize) * k +
      Float(2) * l
    }
    Material { .checkerboard(.silicon, .carbon) }

    for isPositiveX in [false, true] {
      for isPositiveY in [false, true] {
        let halfSize = Float(crossSize) / 2
        let center = halfSize * h + halfSize * k

        let directionX = isPositiveX ? h : -h
        let directionY = isPositiveY ? k : -k
        let halfThickness = Float(crossThickness) / 2

        Volume {
          Concave {
            Convex {
              Origin { center + halfThickness * directionX }
              Plane { isPositiveX ? h : -h }
            }
            Convex {
              Origin { center + halfThickness * directionY }
              Plane { isPositiveY ? k : -k }
            }
          }
          Replace { .empty }
        }
      }
    }
  }

  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)

  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]

    // This offset captures just one Si and one C for each unit cell on the
    // (001) surface. By capture, I mean that atom.position.z > 0. We want a
    // small number of static atoms in a 2 nm voxel that overlaps some moving
    // atoms.
    atom.position += SIMD3(0, 0, -0.800)

    // Shift the origin to allow larger beam depth, with fixed world dimension.
    atom.position.z -= actualWorldDimension / 2
    atom.position.z += 8

    // Shift so the structure is centered in X and Y.
    let latticeConstant = Constant(.square) {
      .checkerboard(.silicon, .carbon)
    }
    let halfSize = Float(crossSize) / 2
    atom.position.x -= halfSize * latticeConstant
    atom.position.y -= halfSize * latticeConstant

    topology.atoms[atomID] = atom
  }

  return topology
}

func createBeam() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds {
      Float(crossThickness) * h +
      Float(crossSize) * k +
      Float(beamDepth) * l
    }
    Material { .checkerboard(.silicon, .carbon) }
  }

  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)

  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]

    // Capture just one Si and one C for each unit cell. This time, capturing
    // happens if atom.position.z < 0.
    atom.position += SIMD3(0, 0, -0.090)

    // Shift so both captured surfaces fall in the [0, 2] nm range for sharing
    // a voxel.
    atom.position.z += 2

    // Shift the origin to allow larger beam depth, with fixed world dimension.
    atom.position.z -= actualWorldDimension / 2
    atom.position.z += 8

    // Shift so the structure is centered in X and Y.
    let latticeConstant = Constant(.square) {
      .checkerboard(.silicon, .carbon)
    }
    let halfThickness = Float(crossThickness) / 2
    let halfSize = Float(crossSize) / 2
    atom.position.x -= halfThickness * latticeConstant
    atom.position.y -= halfSize * latticeConstant

    topology.atoms[atomID] = atom
  }

  return topology
}

func analyze(topology: Topology) {
  print()
  print("atom count:", topology.atoms.count)
  do {
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for atom in topology.atoms {
      let position = atom.position
      minimum.replace(with: position, where: position .< minimum)
      maximum.replace(with: position, where: position .> maximum)
    }
    print("minimum:", minimum)
    print("maximum:", maximum)
  }
}

let cross = createCross()
let beam = createBeam()
analyze(topology: cross)
analyze(topology: beam)

func bounds(topology: Topology) -> (SIMD3<Float>, SIMD3<Float>) {
  var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
  var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
  for atom in topology.atoms {
    let position = atom.position
    minimum.replace(with: position, where: position .< minimum)
    maximum.replace(with: position, where: position .> maximum)
  }
  return (minimum, maximum)
}

let crossBounds = bounds(topology: cross)
let beamBounds = bounds(topology: beam)
var sceneMin = crossBounds.0
var sceneMax = crossBounds.1
sceneMin.replace(with: beamBounds.0, where: beamBounds.0 .< sceneMin)
sceneMax.replace(with: beamBounds.1, where: beamBounds.1 .> sceneMax)

// Orbit around the geometric center of the full scene (cross + beam).
let sceneCenter = (sceneMin + sceneMax) / 2

// Choose orbit radius so that at angle = 0, the camera matches the original view.
let baseCameraPosition = SIMD3<Float>(0, 0, (actualWorldDimension / 2) - 8)
let orbitRadius = ((baseCameraPosition - sceneCenter) * (baseCameraPosition - sceneCenter)).sum().squareRoot()

// MARK: - Rotation Animation

@MainActor
func createRotatedBeam(loopFraction: Float, rotationsPerLoop: Int) -> Topology {
  // Phase-matched looping:
  // - loopFraction goes from 0 -> 1 over the whole GIF
  // - rotationsPerLoop is an integer so the start/end phases match exactly
  let angleDegrees: Float = Float(rotationsPerLoop) * 360 * loopFraction
  let rotation = Quaternion<Float>(
    angle: angleDegrees * Float.pi / 180,
    axis: SIMD3(0, 0, 1))

  // Circumvent a massive CPU-side bottleneck from 'rotation.act()'.
  let basis0 = rotation.act(on: SIMD3<Float>(1, 0, 0))
  let basis1 = rotation.act(on: SIMD3<Float>(0, 1, 0))
  let basis2 = rotation.act(on: SIMD3<Float>(0, 0, 1))

  var topology = beam
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]

    var rotatedPosition: SIMD3<Float> = .zero
    rotatedPosition += basis0 * atom.position[0]
    rotatedPosition += basis1 * atom.position[1]
    rotatedPosition += basis2 * atom.position[2]
    atom.position = rotatedPosition

    topology.atoms[atomID] = atom
  }

  return topology
}

// MARK: - Launch Application

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)

  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  if renderingOffline {
    displayDesc.frameBufferSize = SIMD2<Int>(1080, 1080)
  } else {
    displayDesc.frameBufferSize = SIMD2<Int>(1080, 1080)
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
    // What? We forgot to enable upscaling while originally creating this test?
    // It's better to leave the original code as-is, but it might cause FPS
    // problems on weaker GPUs. Ideally, we would use an upscale factor of 3 and
    // change the code in 'application.run' to call 'application.upscale'.
    //
    // Since the majority of the pixels never intersect an atom, the compute cost
    // for ray tracing is quite low. That's probably why the test didn't cause
    // performance issues.
    applicationDesc.upscaleFactor = 1
  }

  applicationDesc.addressSpaceSize = 4_000_000
  applicationDesc.voxelAllocationSize = 500_000_000
  applicationDesc.worldDimension = paddedWorldDimension
  let application = Application(descriptor: applicationDesc)

  return application
}
let application = createApplication()

for atomID in cross.atoms.indices {
  let atom = cross.atoms[atomID]
  application.atoms[atomID] = atom
}

@MainActor
func addRotatedBeam(loopFraction: Float, rotationsPerLoop: Int) {
  let rotatedBeam = createRotatedBeam(
    loopFraction: loopFraction,
    rotationsPerLoop: rotationsPerLoop)
  let offset = cross.atoms.count

  // Circumvent a massive CPU-side bottleneck from @MainActor referencing to
  // 'application' from the global scope.
  let applicationCopy = application

  for atomID in rotatedBeam.atoms.indices {
    let atom = rotatedBeam.atoms[atomID]
    applicationCopy.atoms[offset + atomID] = atom
  }
}

// MARK: - Main Loop

// This test only supports offline rendering
assert(renderingOffline, "This test only supports offline rendering")

print("Recording rotating beam animation offline - will save as GIF...")
print("Starting animation loop...")

// To get a seamless loop WITHOUT a visible “pause”, do NOT include a duplicate
// endpoint frame. Instead, sample loopFraction over [0, 1) so the wrap from the
// last frame back to the first has the same phase step as every other frame.
let recordedFrameCount = frameCount / gifFrameSkipRate
let orbitRotationsPerLoop: Int = 1
let beamRotationsPerLoop: Int = 3

for recordedFrameID in 0..<recordedFrameCount {
  let loopFraction = Float(recordedFrameID) / Float(recordedFrameCount)
  currentTime = loopFraction * (Float(frameCount) / 60.0)

  addRotatedBeam(loopFraction: loopFraction, rotationsPerLoop: beamRotationsPerLoop)

  // Orbit the camera around the object (Y-axis orbit; circle in the X-Z plane).
  let orbitAngle = 2 * Float.pi * Float(orbitRotationsPerLoop) * loopFraction
  let orbitRotation = Quaternion<Float>(
    angle: orbitAngle,
    axis: SIMD3(0, 1, 0))

  let cameraOffset = SIMD3<Float>(0, 0, orbitRadius)
  application.camera.position = sceneCenter + orbitRotation.act(on: cameraOffset)

  // Camera basis: keep it aligned with the orbit so the camera looks toward the
  // scene the same way it does in the original test at loopFraction = 0.
  application.camera.basis.0 = orbitRotation.act(on: SIMD3<Float>(1, 0, 0))
  application.camera.basis.1 = orbitRotation.act(on: SIMD3<Float>(0, 1, 0))
  application.camera.basis.2 = orbitRotation.act(on: SIMD3<Float>(0, 0, 1))
  application.camera.fovAngleVertical = Float.pi / 180 * 60

  let image = application.render()

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
      delayTime: 5, // ~20 FPS
      localQuantization: OctreeQuantization(fromImage: gifImage)
    )
    gif.frames.append(frame)

  print("Recorded frame \(recordedFrameID + 1) / \(recordedFrameCount)")
}

print("Animation complete, \(gif.frames.count) frames recorded")
print("Encoding GIF...")
let data = try! gif.encoded()
let filePath = "Art/rotating-beam.gif"
let succeeded = FileManager.default.createFile(
  atPath: filePath,
  contents: data
)
if succeeded {
  print("Saved GIF to \(filePath)")
} else {
  print("Failed to save GIF")
}