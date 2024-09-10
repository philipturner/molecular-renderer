// swift package init --type executable
// Copy the following code into 'main.swift'.
// Change the platforms to '[.macOS(.v14)]' in the package manifest.
// swift run -Xswiftc -Ounchecked

// https://www.polpiella.dev/launching-a-swiftui-view-from-the-terminal

// Next steps:
// - Copying the code.
//    - Save the code to a GitHub gist for reference.
//    - Make a cleaned molecular-renderer branch.
//    - Copy the above code into the branch.
//    - Test the code.
//    - Commit the files to Git.
// - Access the GPU.
//   - Modify it to get Metal rendering.
//   - Integrate a CVDisplayLink to get information about the time each frame.
//   - Run a test of timestamp synchronization.
// - Repeat the same process with COM / D3D12 on Windows.

import AppKit

// MARK: - AAPLAppDelegate

class AAPLAppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(
    _ app: NSApplication
  ) -> Bool {
    return true
  }
}

// MARK: - AAPLView

protocol AAPLViewDelegate {
  func resizeDrawable(_ size: CGSize)
  func renderToMetalLayer(metalLayer: CAMetalLayer)
}

class AAPLView: NSView, CALayerDelegate {
  var metalLayer: CAMetalLayer!
  var paused: Bool = false
  var delegate: AAPLViewDelegate!
  
  func initCommon() {
    metalLayer = self.layer! as? CAMetalLayer
    self.layer!.delegate = self
  }
  
  func resizeDrawable(_ scaleFactor: CGFloat) {
    // Fetch the bounds and multiply by the scale factor.
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    
    // Check that the resolved size is what we want.
    if size.width != CGFloat(1920) ||
        size.height != CGFloat(1920) {
      if size.width != 0 ||
          size.height != 0 {
        fatalError("Size cannot change.")
      }
    }
    
    metalLayer.drawableSize = size
    delegate.resizeDrawable(size)
  }
  
  func render() {
    delegate.renderToMetalLayer(metalLayer: metalLayer)
  }
}

// MARK: - AAPLViewController

//class AAPLViewController: NSViewController, AAPLViewDelegate {
//  var renderer: AAPLRenderer!
//}

// MARK: - AAPLRenderer

class AAPLRenderer: NSObject {
  var device: MTLDevice!
  var commandQueue: MTLCommandQueue!
  var computePipelineState: MTLComputePipelineState!
  
  var viewportSize: SIMD2<UInt32> = .zero
  var frameNumber: Int = .zero
  
  init(
    device: MTLDevice,
    drawablePixelFormat: MTLPixelFormat
  ) {
    // Initialize the NSObject.
    super.init()
    
    // Set the device property.
    self.device = device
    
    // Set the command queue property.
    guard let commandQueue = device.makeCommandQueue() else {
      fatalError("Failed to make command queue.")
    }
    self.commandQueue = commandQueue
    
    // Set the PSO property.
    self.computePipelineState = AAPLShaders
      .createComputePipelineState(device: device)
  }
  
  func renderToMetalLayer(metalLayer: CAMetalLayer) {
    
  }
  
  func resizeDrawable(_ drawableSize: CGSize) {
    
  }
}

// MARK: - AAPLShaders

class AAPLShaders {
  static func createSource() -> String {
    """
    
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void renderImage(
      texture2d<half, access::write> drawableTexture [[texture(0)]],
      ushort2 tid [[thread_position_in_grid]]
    ) {
      half4 color = half4(1.00, 0.00, 0.00, 1.00);
      drawableTexture.write(color, tid);
    }
    
    """
  }
  
  static func createComputePipelineState(
    device: MTLDevice
  ) -> MTLComputePipelineState {
    // JIT-compile the shader code into a library.
    let shaderSource = AAPLShaders.createSource()
    let library = try! device.makeLibrary(source: shaderSource, options: nil)
    
    // Load the Metal function.
    let function = library.makeFunction(name: "renderImage")
    guard let function else {
      fatalError("Could not make function.")
    }
    
    // Initialize the pipeline state object.
    let pipeline = try! device.makeComputePipelineState(function: function)
    return pipeline
  }
}

// MARK: - Launching the Application

// Run the application.
let appDelegate = AAPLAppDelegate()
withExtendedLifetime(appDelegate) {
  let app = NSApplication.shared
  app.delegate = appDelegate
  app.setActivationPolicy(.regular)
  app.activate(ignoringOtherApps: true)
  app.run()
}


