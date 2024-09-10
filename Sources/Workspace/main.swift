// swift package init --type executable
// Copy the following code into 'main.swift'.
// Change the platforms to '[.macOS(.v14)]' in the package manifest.
// swift run -Xswiftc -Ounchecked

// https://www.polpiella.dev/launching-a-swiftui-view-from-the-terminal

import AppKit
import SwiftUI

// Launching a SwiftUI view from the command line.
// - Use AppKit's 'NSApplication' class.
// - Create a new instance of 'NSWindow'.
// - Set the 'contentViewController' to an 'NSHostingView'
// - The 'NSHostingView' wraps the SwiftUI view.

// Rounded rectangle filled with the input color, and labeled hex value.
struct ColorDisplay: View {
  var body: some View {
    ZStack {
      Rectangle()
        .fill(.cyan.opacity(0.4).gradient)
      VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 20)
          .fill(.cyan)
          .frame(width: 300, height: 300)
          .shadow(color: .black.opacity(0.15), radius: 10)
        
        Text(Color.cyan.description)
          .font(.largeTitle)
          .fontWeight(.heavy)
          .fontDesign(.rounded)
      }
      
    }
    .frame(width: 600, height: 600)
  }
}

// Creates a new 'NSWindow' instance, sets its content view to a hosting view.
final class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  
  override init() {
    
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.closable, .resizable, .titled],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = NSHostingController(
      rootView: ColorDisplay()
    )
    window.makeKey()
    window.center()
    window.orderFrontRegardless()
    window.title = "🎨 Hex - \(Color.cyan.description)"
    self.window = window
  }
}

// Run the application.
let appDelegate = AppDelegate()
withExtendedLifetime(appDelegate) {
  let app = NSApplication.shared
  app.delegate = appDelegate
  app.setActivationPolicy(.regular)
  app.activate(ignoringOtherApps: true)
  app.run()
}

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
