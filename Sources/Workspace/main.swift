// Tasks:
// - Retrieve the atom radii and colors ("atom styles") from the old renderer.
//   Put them in the workspace for now, until we figure out everything else.
// - Render an isopropanol molecule in this paradigm:
//   https://github.com/nutjunkie/IQmol/blob/master/share/fragments/Molecules/Alcohols/Isopropanol.xyz

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

// Set up the application.
let application = createApplication()

// Set up the shader.
var shaderDesc = ShaderDescriptor()
shaderDesc.device = application.device
shaderDesc.name = "renderImage"
shaderDesc.source = createRenderImage()
#if os(macOS)
shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
#endif
let shader = Shader(descriptor: shaderDesc)

// C: (0.388, 0.388, 0.388), 0.1426 nm
// O: (0.502, 0.000, 0.000), 0.1349 nm

do {
  let colors = AtomStyles.createColors()
  let radii = AtomStyles.createRadii()
  // print(colors[8])
  // print(radii[8])
}

// Enter the run loop.
application.run { renderTarget in
  application.device.commandQueue.withCommandList { commandList in
    // Encode the compute command.
    commandList.withPipelineState(shader) {
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
