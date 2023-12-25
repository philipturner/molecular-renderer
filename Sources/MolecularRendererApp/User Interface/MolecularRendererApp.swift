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
      width: ContentView.size / NSScreen.main!.backingScaleFactor,
      height: ContentView.size / NSScreen.main!.backingScaleFactor)
  }
}

struct ContentView: View {
  @ObservedObject var coordinator: Coordinator
  
  static let upscaleFactor: Int = {
    if #available(macOS 14, iOS 17, tvOS 17, *) {
      return 3
    } else {
      return 2
    }
  }()
  
  static let frameRate: Int = 120
  
  static let size: CGFloat = 640 * CGFloat(upscaleFactor)
  
  var body: some View {
    // A ZStack to overlay the crosshair over the scene view
    ZStack {
      // A NSViewRepresentable to wrap the scene view
      MetalView(coordinator: coordinator)
        .disabled(false)
        .frame(
          width: ContentView.size / NSScreen.main!.backingScaleFactor,
          height: ContentView.size / NSScreen.main!.backingScaleFactor)
        .position(
          x: ContentView.size / 2 / NSScreen.main!.backingScaleFactor,
          y: ContentView.size / 2 / NSScreen.main!.backingScaleFactor)
      
      // A conditional view to show or hide the crosshair
      if coordinator.showCrosshair {
        CrosshairView(coordinator: coordinator)
      }
    }
    .padding(.zero)
  }
}
