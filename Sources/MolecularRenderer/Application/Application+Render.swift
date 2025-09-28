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
  private func writeCameraArgs() {
    var currentCameraArgs = CameraArgs()
    currentCameraArgs.position = (
      camera.position[0],
      camera.position[1],
      camera.position[2])
    currentCameraArgs.tangentFactor = tan(camera.fovAngleVertical / 2)
    currentCameraArgs.basis = camera.basis
    
    let previousCameraArgs = resources.previousCameraArgs ?? currentCameraArgs
    let cameraArgsList = [currentCameraArgs, previousCameraArgs]
    resources.cameraArgsBuffer.write(
      data: cameraArgsList,
      inFlightFrameID: frameID % 3)
    
    resources.previousCameraArgs = currentCameraArgs
  }
  
  // Returns the atom count for binding the constant arguments.
  private func writeAtoms() -> Int {
    let transaction = atoms.registerChanges()
    resources.transactionTracker.register(transaction: transaction)
    let atoms = resources.transactionTracker.compactedAtoms()
    
    resources.atomBuffer.write(
      data: atoms,
      inFlightFrameID: frameID % 3)
    return atoms.count
  }
  
  public func render() -> Image {
    writeCameraArgs()
    let atomCount = writeAtoms()
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      resources.cameraArgsBuffer.copy(
        commandList: commandList,
        inFlightFrameID: frameID % 3)
      resources.atomBuffer.copy(
        commandList: commandList,
        inFlightFrameID: frameID % 3)
      #endif
      
      // Bind the descriptor heap.
      #if os(Windows)
      commandList.setDescriptorHeap(resources.descriptorHeap)
      #endif
      
      // Encode the compute command.
      commandList.withPipelineState(resources.renderShader) {
        // Bind the constant arguments.
        var constantArgs = ConstantArgs()
        constantArgs.atomCount = UInt32(atomCount)
        constantArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
        commandList.set32BitConstants(
          constantArgs, index: RenderShader.constantArgs)
        
        // Bind the camera args buffer.
        let cameraArgsBuffer = resources.cameraArgsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          cameraArgsBuffer, index: RenderShader.cameraArgs)
        
        // Bind the atom buffer.
        let atomBuffer = resources.atomBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          atomBuffer, index: RenderShader.atoms)
        
        // Bind the color texture.
        #if os(macOS)
        let colorTexture = renderTarget.colorTextures[frameID % 2]
        commandList.mtlCommandEncoder.setTexture(
          colorTexture, index: RenderShader.colorTexture)
        #else
        commandList.setDescriptor(
          handleID: frameID % 2, index: RenderShader.colorTexture)
        #endif
        
        // Bind the depth and motion textures.
        if renderTarget.upscaleFactor > 1 {
          #if os(macOS)
          let depthTexture = renderTarget.depthTextures[frameID % 2]
          let motionTexture = renderTarget.motionTextures[frameID % 2]
          commandList.mtlCommandEncoder.setTexture(
            depthTexture, index: RenderShader.depthTexture)
          commandList.mtlCommandEncoder.setTexture(
            motionTexture, index: RenderShader.motionTexture)
          #else
          commandList.setDescriptor(
            handleID: 2 + frameID % 2, index: RenderShader.depthTexture)
          commandList.setDescriptor(
            handleID: 4 + frameID % 2, index: RenderShader.motionTexture)
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
