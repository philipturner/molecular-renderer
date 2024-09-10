//
//  MolecularRendererApp.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import SwiftUI

@main
struct MolecularRendererApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(coordinator: Coordinator())
        .fixedSize(horizontal: true, vertical: true)
    }
    .windowResizability(.contentSize)
    .defaultSize(
      width: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor,
      height: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor)
  }
}

struct ContentView: View {
  @ObservedObject var coordinator: Coordinator
  
  // MARK: - Users, set this to match your device's display refresh rate.
  // MacBooks with ProMotion are typically 120 Hz, but most over devices are
  // 60 Hz. It is important to set the right framerate, because all
  // animations require synchronization (Vsync) with integer multiples of the
  // frame rate.
  //
  // This goes beyond just avoiding frame tearing (the common reason to use
  // Vsync). It is for replaying timed animations where every frame is
  // initialized beforehand. You plan out how many frames to generate based on
  // the number of seconds, and the number of frames per second. The CFRunLoop
  // is not called at exact integer multiples of the frame rate (often slightly
  // off by an unpredictable fraction of a frame). Setting the correct frame
  // rate is the only way to map the current frame index to the correct
  // position in a pre-compiled sequence of frames.
  static let frameRate: Int = 120
  
  // MARK: - Users, scale this down to match your device's GPU compute power.
  // For example, the M1 Max (32 cores) can handle a 640 x 640 square window
  // at 120 Hz. The M1 (8 cores) could suffice with half the pixel count
  // (480 x 480) and half the framerate (60 Hz). Here is a loose recommendation
  // for display setup.
  //
  // ## Laptops
  //
  // M1/M2/M3 (~8 cores), 60 Hz MacBook
  // M1/M2/M3 (~8 cores), Mac mini, 60 Hz external monitor
  // - 480 x 480 (upscales to 1440 x 1440)
  //
  //           M3  (10 cores), 120 Hz MacBook (14")
  // M1/M2/M3 Pro (~16 cores), 120 Hz MacBook
  // - 480 x 480 (upscales to 1440 x 1440)
  //
  // M2/M3 Pro      (~16 cores), Mac mini, 60 Hz external monitor
  // M1/M2/M3 Max   (~32 cores), 120 Hz MacBook
  // M1/M2/M3 Ultra (~64 cores), 60-144 Hz external monitor
  // - 640 x 640 (upscales to 1920 x 1920)
  //
  static let size: Int = 1920
  
  var body: some View {
    // A ZStack to overlay the crosshair over the scene view
    ZStack {
      // A NSViewRepresentable to wrap the scene view
      MetalView(coordinator: coordinator)
        .disabled(false)
        .frame(
          width: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor,
          height: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor)
        .position(
          x: CGFloat(ContentView.size) / 2 / NSScreen.main!.backingScaleFactor,
          y: CGFloat(ContentView.size) / 2 / NSScreen.main!.backingScaleFactor)
      
      // A conditional view to show or hide the crosshair
      if coordinator.showCrosshair {
        CrosshairView(coordinator: coordinator)
      }
    }
    .padding(.zero)
  }
}
