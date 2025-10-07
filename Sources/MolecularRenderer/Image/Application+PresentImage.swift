#if os(macOS)
import Metal
import protocol QuartzCore.CAMetalDrawable
#else
import SwiftCOM
import WinSDK
#endif

#if os(Windows)
private func presentImageTransition(
  resource: SwiftCOM.ID3D12Resource,
  before: D3D12_RESOURCE_STATES,
  after: D3D12_RESOURCE_STATES
) -> D3D12_RESOURCE_BARRIER {
  // Specify the type of barrier.
  var barrier = D3D12_RESOURCE_BARRIER()
  barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
  barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
  
  // Specify the transition's parameters.
  try! resource.perform(
    as: WinSDK.ID3D12Resource.self
  ) { pUnk in
    barrier.Transition.pResource = pUnk
  }
  barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
  barrier.Transition.StateBefore = before
  barrier.Transition.StateAfter = after
  
  return barrier
}
#endif

extension Application {
  public func present(image: Image) {
    guard image.scaleFactor == imageResources.renderTarget.upscaleFactor else {
      fatalError("Received image with incorrect scale factor.")
    }
    
    func createFrontBuffer() -> RenderTarget.Texture {
      let frontBufferID = frameID % 2
      if imageResources.renderTarget.upscaleFactor == 1 {
        return imageResources.renderTarget.colorTextures[frontBufferID]
      } else {
        return imageResources.renderTarget.upscaledTextures[frontBufferID]
      }
    }
    let frontBuffer = createFrontBuffer()
    
    #if os(macOS)
    func retrieveDrawable() -> CAMetalDrawable {
      let layer = view.metalLayer
      let drawable = layer.nextDrawable()
      guard let drawable else {
        fatalError("Drawable timed out after 1 second.")
      }
      return drawable
    }
    let drawable = retrieveDrawable()
    
    // Copy the front buffer to the back buffer and present.
    device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      
      let commandEncoder: MTLBlitCommandEncoder =
      commandList.mtlCommandBuffer.makeBlitCommandEncoder()!
      commandEncoder.copy(
        from: frontBuffer,
        to: drawable.texture)
      commandEncoder.endEncoding()
      
      commandList.mtlCommandBuffer.present(drawable)
      
      commandList.mtlCommandEncoder =
      commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    }
    #else
    // Retrieve the back buffer.
    func retrieveBackBuffer() -> SwiftCOM.ID3D12Resource {
      let backBufferID = try! swapChain.d3d12SwapChain
        .GetCurrentBackBufferIndex()
      return swapChain.backBuffers[Int(backBufferID)]
    }
    let backBuffer = retrieveBackBuffer()
    
    // Copy the front buffer to the back buffer.
    device.commandQueue.withCommandList { commandList in
      // Transitions before the copy command.
      do {
        let barrier1 = presentImageTransition(
          resource: frontBuffer,
          before: D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
          after: D3D12_RESOURCE_STATE_COPY_SOURCE)
        let barrier2 = presentImageTransition(
          resource: backBuffer,
          before: D3D12_RESOURCE_STATE_PRESENT,
          after: D3D12_RESOURCE_STATE_COPY_DEST)
        let barriers = [barrier1, barrier2]
        
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
      
      try! commandList.d3d12CommandList.CopyResource(
        backBuffer, // pDstResource
        frontBuffer) // pSrcResource
      
      // Transition after the copy command.
      do {
        let barrier1 = presentImageTransition(
          resource: frontBuffer,
          before: D3D12_RESOURCE_STATE_COPY_SOURCE,
          after: D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
        let barrier2 = presentImageTransition(
          resource: backBuffer,
          before: D3D12_RESOURCE_STATE_COPY_DEST,
          after: D3D12_RESOURCE_STATE_PRESENT)
        let barriers = [barrier1, barrier2]
        
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
    }
    
    // Present the back buffer.
    try! swapChain.d3d12SwapChain.Present(1, 0)
    #endif
  }
}
