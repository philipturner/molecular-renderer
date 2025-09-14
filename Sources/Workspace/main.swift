// Goal:
// - Start with a UInt32 buffer holding the atomic numbers, read instead of the
//   actual atomic numbers baked into shader code.
// - Migrate to R16_UINT / R16_FLOAT testing with RWBuffer.
// - Migrate the rest of the data and make atom count defined at runtime.
//
// Sources:
// - https://www.gamedev.net/forums/topic/678018-rwbuffer-vs-rwstructuredbuffer-or-rwbyteaddressbuffer/
// - https://gist.github.com/philipturner/7f2b3da4ae719bb28d3b60ebfc1e0f60
// - https://gist.github.com/philipturner/ec3138aaf69d44a46e610a4a0a7a6af2
// - https://darkcorners.dev/buffers-vs-structuredbuffers

import HDL
import MolecularRenderer
#if os(macOS)
import Metal
#else
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
  applicationDesc.device = device
  applicationDesc.display = display
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

func createAtoms() -> [SIMD4<Float>] {
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
let atoms = createAtoms()

// Set up the atom buffer.
var bufferDesc = BufferDescriptor()
bufferDesc.device = application.device
bufferDesc.size = atoms.count * 4

#if os(Windows)
bufferDesc.type = .input
let inputAtomBuffer = Buffer(descriptor: bufferDesc)
#endif

bufferDesc.type = .native
let nativeAtomBuffer = Buffer(descriptor: bufferDesc)

// Write the contents of the atom buffer.
do {
  var contents: [UInt32] = []
  for atom in atoms {
    let atomicNumber = UInt32(atom[3])
    contents.append(atomicNumber)
  }
  
  contents.withUnsafeBytes { bufferPointer in
    let baseAddress = bufferPointer.baseAddress!
    #if os(macOS)
    nativeAtomBuffer.write(input: baseAddress)
    #else
    inputAtomBuffer.write(input: baseAddress)
    #endif
  }
}

#if os(Windows)
application.device.commandQueue.withCommandList { commandList in
  commandList.upload(
    inputBuffer: inputAtomBuffer,
    nativeBuffer: nativeAtomBuffer)
  
  let unorderedAccessBarrier = nativeAtomBuffer
    .transition(state: D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
  try! commandList.d3d12CommandList.ResourceBarrier(
    1, [unorderedAccessBarrier])
}
#endif

// Set up the shader.
var shaderDesc = ShaderDescriptor()
shaderDesc.device = application.device
shaderDesc.name = "renderImage"
shaderDesc.source = createRenderImage(atoms: atoms)
#if os(macOS)
shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
#endif
let shader = Shader(descriptor: shaderDesc)

// Enter the run loop.
#if os(macOS)
application.run { _ in
#else
application.run { renderTarget in
#endif
  application.device.commandQueue.withCommandList { commandList in
    // Encode the compute command.
    commandList.withPipelineState(shader) {
      // Bind the texture.
      #if os(macOS)
      commandList.mtlCommandEncoder
        .setTexture(renderTarget, index: 0)
      #else
      try! commandList.d3d12CommandList
        .SetDescriptorHeaps([renderTarget])
      let gpuDescriptorHandle = try! renderTarget
        .GetGPUDescriptorHandleForHeapStart()
      try! commandList.d3d12CommandList
        .SetComputeRootDescriptorTable(0, gpuDescriptorHandle)
      #endif
      
      // Conventions:
      // - one descriptor table per UAV
      // - lazily initialize the handle ID in client code
      // - Remove the macOS-specific 'renderTarget' argument from
      //   application.run. We can always change this later for pipelined
      //   offline rendering. But for now, simplicity matters more.
      //
      // DescriptorHeapDescriptor
      // - specify the number of descriptors
      // DescriptorHeap
      // - createView(ID3D12Resource, D3D12_UAV_DESC) -> Int
      // commandList.setDescriptorHeap
      // commandList.setDescriptor(handleID: Int, index: Int)
      // - under the hood, retrieves the GPU descriptor handle from the heap
      //   bound to the command list
      
      // Bind the atoms.
      commandList.setBuffer(
        nativeAtomBuffer, index: 1)
      
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
}
