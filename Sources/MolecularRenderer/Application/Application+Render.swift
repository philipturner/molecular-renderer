import func Foundation.tan

#if os(Windows)
import SwiftCOM
import WinSDK
#endif

#if os(Windows)
private func renderUAVBarrier(
  resource: SwiftCOM.ID3D12Resource
) -> D3D12_RESOURCE_BARRIER {
  // Specify the type of barrier.
  var barrier = D3D12_RESOURCE_BARRIER()
  barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV
  barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
  
  // Specify the UAV barrier's parameters.
  try! resource.perform(
    as: WinSDK.ID3D12Resource.self
  ) { pUnk in
    barrier.UAV.pResource = pUnk
  }
  
  return barrier
}
#endif

extension Application {
  public func render() -> Image {
    let transaction = atoms.registerChanges()
    resources.transactionTracker.register(transaction: transaction)
    let atoms = resources.transactionTracker.compactedAtoms()
    
    // Write the atoms to the GPU buffer.
    let inFlightFrameID = frameID % 3
    resources.atomBuffer.write(
      atoms: atoms,
      inFlightFrameID: inFlightFrameID)
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      resources.atomBuffer.copy(
        commandList: commandList,
        inFlightFrameID: inFlightFrameID)
      #endif
      
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(resources.descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(resources.renderShader) {
        // Bind the constant arguments.
        var constantArgs = ConstantArgs()
        constantArgs.atomCount = UInt32(atoms.count)
        constantArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
        constantArgs.tangentFactor = tan(camera.fovAngleVertical / 2)
        constantArgs.cameraPosition = camera.position
        constantArgs.cameraBasis = camera.basis
        commandList.set32BitConstants(constantArgs, index: 0)
        
        // Bind the atom buffer.
        let nativeBuffer = resources.atomBuffer.nativeBuffers[inFlightFrameID]
        commandList.setBuffer(nativeBuffer, index: 1)
        
        // Bind the color texture.
        #if os(macOS)
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        commandList.mtlCommandEncoder.setTexture(
          colorTexture, index: 2)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2, index: 2)
        #endif
        
        // Bind the depth and motion textures.
        if renderTarget.upscaleFactor > 1 {
          #if os(macOS)
          let depthTexture = renderTarget.depthTextures[frameID % 2]
          let motionTexture = renderTarget.motionTextures[frameID % 2]
          commandList.mtlCommandEncoder.setTexture(
            depthTexture, index: 3)
          commandList.mtlCommandEncoder.setTexture(
            motionTexture, index: 4)
          #else
          commandList.setDescriptor(
            handleID: 2 + frameID % 2, index: 3)
          commandList.setDescriptor(
            handleID: 4 + frameID % 2, index: 4)
          #endif
        }
        
        // Determine the dispatch grid size.
        func createGroupCount32() -> SIMD3<UInt32> {
          let groupSize = SIMD2<Int>(8, 8)
          
          var groupCount = renderTarget.intermediateSize(display: display)
          groupCount &+= groupSize &- 1
          groupCount /= groupSize
          
          return SIMD3<UInt32>(
            UInt32(groupCount[0]),
            UInt32(groupCount[1]),
            UInt32(1))
        }
        commandList.dispatch(groups: createGroupCount32())
      }
      
      #if os(Windows)
      // Ensure the output texture(s) are fully written before future
      // operations.
      if renderTarget.upscaleFactor > 1 {
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        let depthTexture = renderTarget.depthTextures[frameID % 2]
        let motionTexture = renderTarget.motionTextures[frameID % 2]
        
        let colorBarrier = renderUAVBarrier(resource: colorTexture)
        let depthBarrier = renderUAVBarrier(resource: depthTexture)
        let motionBarrier = renderUAVBarrier(resource: motionTexture)
        
        let barriers = [colorBarrier, depthBarrier, motionBarrier]
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
      #endif
    }
    
    var output = Image()
    output.scaleFactor = 1
    return output
  }
}
