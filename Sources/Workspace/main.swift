// Goal:
// - Migrate the rest of the data and make atom count defined at runtime.
// - Render an isopropanol molecule rotating and take a video.
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
bufferDesc.size = atoms.count * 2

#if os(Windows)
bufferDesc.type = .input
let inputAtomBuffer = Buffer(descriptor: bufferDesc)
#endif

bufferDesc.type = .native
let nativeAtomBuffer = Buffer(descriptor: bufferDesc)

// Write the contents of the atom buffer.
do {
  var contents: [Float16] = []
  for atom in atoms {
    let atomicNumber = Float16(atom[3])
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

#if os(Windows)
// Set up the descriptor heap.
func createDescriptorHeap(
  device: Device,
  renderTarget: RenderTarget,
  nativeAtomBuffer: Buffer
) -> DescriptorHeap {
  var descriptorHeapDesc = DescriptorHeapDescriptor()
  descriptorHeapDesc.device = device
  descriptorHeapDesc.count = 3
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
  
  // Set up the buffers with compressed memory formats.
  do {
    var uavDesc = D3D12_UNORDERED_ACCESS_VIEW_DESC()
    uavDesc.Format = DXGI_FORMAT_R16_FLOAT
    uavDesc.ViewDimension = D3D12_UAV_DIMENSION_BUFFER
    uavDesc.Buffer.FirstElement = 0
    uavDesc.Buffer.NumElements = UInt32(nativeAtomBuffer.size / 2)
    uavDesc.Buffer.StructureByteStride = 0
    
    let handleID = descriptorHeap.createUAV(
      resource: nativeAtomBuffer.d3d12Resource,
      uavDesc: uavDesc)
    guard handleID == 2 else {
      fatalError("This should never happen.")
    }
  }
  
  return descriptorHeap
}
let descriptorHeap = createDescriptorHeap(
  device: application.device,
  renderTarget: application.renderTarget,
  nativeAtomBuffer: nativeAtomBuffer)
#endif

// Enter the run loop.
application.run {
  // Retrieve the front buffer.
  let frontBufferID = application.frameID % 2
  let frontBuffer = application.renderTarget.colorTextures[frontBufferID]
  
  application.device.commandQueue.withCommandList { commandList in
    // Bind the descriptor heap.
    #if os(Windows)
    commandList.setDescriptorHeap(descriptorHeap)
    #endif
    
    // Encode the compute command.
    commandList.withPipelineState(shader) {
      // Bind the texture.
      #if os(macOS)
      commandList.mtlCommandEncoder
        .setTexture(frontBuffer, index: 0)
      #else
      commandList.setDescriptor(
        handleID: frontBufferID, index: 0)
      #endif
      
      // Bind the atom buffer.
      #if os(macOS)
      commandList.setBuffer(nativeAtomBuffer, index: 1)
      #else
      commandList.setDescriptor(handleID: 2, index: 1)
      #endif
      
      // Bind the constant arguments.
      let atomCount = UInt32(atoms.count)
      commandList.set32BitConstants(atomCount, index: 2)
      
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
