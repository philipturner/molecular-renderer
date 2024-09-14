// Next steps:
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible. [DONE]
//   - Get timestamps synchronizing properly (moving rainbow banner
//     scene).
// - Repeat the same process with COM / D3D12 on Windows.
//   - Get some general experience with C++ DirectX sample code.
//   - Modify the files one-by-one to support Windows.

import MolecularRenderer

// Set up the display.
var display: Display
do {
  let screen = Display.findFastestScreen()
  let screenID = Display.screenID(screen: screen)
  
  var displayDesc = DisplayDescriptor()
  displayDesc.renderTargetSize = 1920
  displayDesc.screenID = screenID
  display = Display(descriptor: displayDesc)
}

// Set up the application.
var application: Application
do {
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.display = display
  application = Application(descriptor: applicationDesc)
}

// Run the application.
application.run()
