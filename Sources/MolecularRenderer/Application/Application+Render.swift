import func Foundation.tan

#if os(Windows)
import SwiftCOM
import WinSDK
#endif

#if os(Windows)
// TODO: Generic UAV barrier after every single kernel while building the
// acceleration structure.
private func renderUAVBarrier() -> D3D12_RESOURCE_BARRIER {
  // Specify the type of barrier.
  var barrier = D3D12_RESOURCE_BARRIER()
  barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_UAV
  barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
  barrier.UAV.pResource = nil
  return barrier
}
#endif

extension Application {
  /*
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
    
    let atoms = resources.transactionTracker
      .compactedAtoms()
    resources.atomsBuffer.write(
      data: atoms,
      inFlightFrameID: frameID % 3)
    
    let motionVectors = resources.transactionTracker
      .compactedMotionVectors()
    resources.motionVectorsBuffer.write(
      data: motionVectors,
      inFlightFrameID: frameID % 3)
    return atoms.count
  }
  
  private func createJitterOffset() -> SIMD2<Float> {
    guard renderTarget.upscaleFactor > 1 else {
      return SIMD2<Float>.zero
    }
    
    var jitterOffsetDesc = JitterOffsetDescriptor()
    jitterOffsetDesc.index = frameID
    jitterOffsetDesc.upscaleFactor = renderTarget.upscaleFactor
    
    return JitterOffset.create(descriptor: jitterOffsetDesc)
  }
   */
  
  public func render() -> Image {
    /*
    writeCameraArgs()
    let atomCount = writeAtoms()
    
    device.commandQueue.withCommandList { commandList in
      #if os(Windows)
      resources.cameraArgsBuffer.copy(
        commandList: commandList,
        inFlightFrameID: frameID % 3)
      resources.atomsBuffer.copy(
        commandList: commandList,
        inFlightFrameID: frameID % 3)
      resources.motionVectorsBuffer.copy(
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
        constantArgs.atomCount = 0 // Deactivate rendering.
        constantArgs.frameSeed = UInt32.random(in: 0..<UInt32.max)
        constantArgs.jitterOffset = createJitterOffset()
        commandList.set32BitConstants(
          constantArgs, index: RenderShader.constantArgs)
        
        // Bind the camera args buffer.
        let cameraArgsBuffer = resources.cameraArgsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          cameraArgsBuffer, index: RenderShader.cameraArgs)
        
        // Bind the atom buffer.
        let atomBuffer = resources.atomsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          atomBuffer, index: RenderShader.atoms)
        
        // Bind the motion vectors buffer.
        #if os(macOS)
        let motionVectorsBuffer = resources.motionVectorsBuffer
          .nativeBuffers[frameID % 3]
        commandList.setBuffer(
          motionVectorsBuffer, index: RenderShader.motionVectors)
        #else
        commandList.setDescriptor(
          handleID: resources.motionVectorsBaseHandleID + frameID % 3,
          index: RenderShader.motionVectors)
        #endif
        
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
      do {
        let barriers = [renderUAVBarrier()]
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
      #endif
    }
     */
    
    var output = Image()
    output.scaleFactor = 1
    return output
  }
}
