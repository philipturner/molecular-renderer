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

// MARK: - AAPLView

protocol AAPLViewDelegate {
  func drawableResize(size: CGSize)
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
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    
    if size.width != CGFloat(1920) ||
        size.height != CGFloat(1920) {
      if size.width != 0 ||
          size.height != 0 {
        fatalError("Size cannot change.")
      }
    }
  }
  
  func render() {
    delegate.renderToMetalLayer(metalLayer: metalLayer)
  }
}

// MARK: - AAPLAppDelegate

final class AAPLAppDelegate: NSObject, NSApplicationDelegate {
  override init() {
    super.init()
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


