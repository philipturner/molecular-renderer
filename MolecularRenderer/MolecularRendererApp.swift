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
      ContentView()
        .fixedSize(horizontal: true, vertical: true)
    }
    .windowResizability(.contentSize)
    .defaultSize(
      width: ContentView.size / NSScreen.main!.backingScaleFactor,
      height: ContentView.size / NSScreen.main!.backingScaleFactor)
  }
}
