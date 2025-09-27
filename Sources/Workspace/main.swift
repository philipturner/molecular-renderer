// Tasks:
// - Next, add perspective projection and force it to be enabled for all
//   renders. FidelityFX requires parameters about FOV and near/far distance.
// - Eventual ergonomic API should accept an angle in radians instead of
//   degrees, with a simpler name than "fov***InDegrees".
//   'cameraFovAngleVertical', copied from the AMD FidelityFX API, is a great
//   idea.
// - The critical distance heuristic from the original renderer is actually
//   quite based. Include it and correct / delete / migrate the documentation
//   currently on the README.
//
// Precursor task:
// - Restructure the user-side API into something much closer to the final form.
// - Not yet supporting offline / flexible workflows that expose the raw image
//   pixel data.
// - Figure out the right API for entering atoms, which can support the
//   far-future option of in-place modification to an acceleration structure.

// Plan:
// - Migrate AtomBuffer and TransactionTracker into the library, under a
//   folder titled 'Atoms'. Make these data types 'public' to facilitate the
//   step-wise migration.
// - Bring out the place there the MTLDrawable is presented to a dedicated
//   public API function. Don't yet create the syntax that emulates
//   operations on an image like a physical object tossed around in client code.
// - Migrate much of the code in this file into the library.
// - Restructure the function signatures of the public functions for rendering
//   and presenting.
// - Keep the APIs 'public' scoped for the time being.

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
  displayDesc.frameBufferSize = SIMD2<Int>(1920, 1920)
  #else
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1440)
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

#if os(Windows)
// Set up the descriptor heap.
func createDescriptorHeap(
  device: Device,
  renderTarget: RenderTarget
) -> DescriptorHeap {
  var descriptorHeapDesc = DescriptorHeapDescriptor()
  descriptorHeapDesc.device = device
  descriptorHeapDesc.count = 2
  let descriptorHeap = DescriptorHeap(descriptor: descriptorHeapDesc)
  
  // Set up the textures for rendering.
  for i in 0..<2 {
    let colorTexture = renderTarget.colorTextures[i]
    let handleID = descriptorHeap.createUAV(
      resource: colorTexture,
      uavDesc: nil)
    guard handleID == i else {
      fatalError("This should never happen.")
    }
  }
  
  return descriptorHeap
}
let descriptorHeap = createDescriptorHeap(
  device: application.device,
  renderTarget: application.renderTarget)
#endif

var atomBuffer = AtomBuffer(
  device: application.device,
  atomCount: 1000)

// MARK: - Rendered Content

// State variable to facilitate atom transactions for the animation.
enum AnimationState {
  case isopropanol
  case silane
}
nonisolated(unsafe)
var animationState: AnimationState?
nonisolated(unsafe)
var transactionTracker = TransactionTracker(atomCount: 1000)

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

func createRotatedIsopropanol(time: Float) -> [SIMD4<Float>] {
  // 0.5 Hz rotation rate
  let angle = 0.5 * time * (2 * Float.pi)
  let rotation = Quaternion<Float>(
    angle: angle,
    axis: SIMD3(0.00, 1.00, 0.00))
  
  var output = createIsopropanol()
  for atomID in output.indices {
    var atom = output[atomID]
    atom.position = rotation.act(on: atom.position)
    output[atomID] = atom
  }
  return output
}

func createRotatedSilane(time: Float) -> [SIMD4<Float>] {
  // 0.5 Hz rotation rate
  let angle = 0.5 * time * (2 * Float.pi)
  let rotation = Quaternion<Float>(
    angle: angle,
    axis: SIMD3(0.00, 1.00, 0.00))
  
  var output = createSilane()
  for atomID in output.indices {
    var atom = output[atomID]
    atom.position = rotation.act(on: atom.position)
    output[atomID] = atom
  }
  return output
}

// MARK: - Run Loop

// Enter the run loop.
application.run {
  func createTime(application: Application) -> Float {
    let elapsedFrames = application.clock.frames
    let frameRate = application.display.frameRate
    let seconds = Float(elapsedFrames) / Float(frameRate)
    return seconds
  }
  
  func modifyAtoms(application: Application) {
    let time = createTime(application: application)
    
    let roundedDownTime = Int(time.rounded(.down))
    if roundedDownTime % 2 == 0 {
      let isopropanol = createRotatedIsopropanol(time: time)
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
      let silane = createRotatedSilane(time: time)
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
  
  modifyAtoms(application: application)
  let transaction = application.atoms.registerChanges()
  transactionTracker.register(transaction: transaction)
  let atoms = transactionTracker.compactedAtoms()
  
  // Write the atoms to the GPU buffer.
  let inFlightFrameID = application.frameID % 3
  atomBuffer.write(
    atoms: atoms,
    inFlightFrameID: inFlightFrameID)
  
  // Retrieve the front buffer.
  let frontBufferID = application.frameID % 2
  let frontBuffer = application.renderTarget.colorTextures[frontBufferID]
  
  application.device.commandQueue.withCommandList { commandList in
    #if os(Windows)
    atomBuffer.copy(
      commandList: commandList,
      inFlightFrameID: inFlightFrameID)
    #endif
    
    // Bind the descriptor heap.
    #if os(Windows)
    commandList.setDescriptorHeap(descriptorHeap)
    #endif
    
    // Encode the compute command.
    commandList.withPipelineState(application.resources.shader) {
      // Bind the texture.
      #if os(macOS)
      commandList.mtlCommandEncoder
        .setTexture(frontBuffer, index: 0)
      #else
      commandList.setDescriptor(
        handleID: frontBufferID, index: 0)
      #endif
      
      // Bind the atom buffer.
      let nativeBuffer = atomBuffer.nativeBuffers[inFlightFrameID]
      commandList.setBuffer(nativeBuffer, index: 1)
      
      // Bind the constant arguments.
      struct ConstantArgs {
        var atomCount: UInt32
        var frameSeed: UInt32
      }
      let constantArgs = ConstantArgs(
        atomCount: UInt32(atoms.count),
        frameSeed: .random(in: 0..<UInt32.max))
      commandList.set32BitConstants(constantArgs, index: 2)
      
      // Determine the dispatch grid size.
      let frameBufferSize = application.display.frameBufferSize
      let groupSize = SIMD2<Int>(8, 8)
      
      var groupCount = frameBufferSize
      groupCount &+= groupSize &- 1
      groupCount /= groupSize
      
      let groupCount32 = SIMD3<UInt32>(
        UInt32(groupCount[0]),
        UInt32(groupCount[1]),
        UInt32(1))
      commandList.dispatch(groups: groupCount32)
    }
  }
  
  application.present()
}
