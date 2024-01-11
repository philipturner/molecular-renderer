//
//  NanoRobotPartPlacement.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/10/24.
//

import MM4

// Reproduce Tom Moore's nano-robot part placement, export to a video.
// - Litmus test of the new MM4ForceField implementation
// - Experiment with new serialization/video exporting workflows
//   - Base64 or no serialization at all
//   - iPhone recording to show real-time FPS monitor
//
// Details:
// - Reproduce the video subtitles.
//   - MD Package: OpenMM
//   - FF: Molecular Mechanics 4
//   - 13,054 Atoms, 10.0 ms Compile Time
//   - Rendered with Apple Metal
// - Copy the exact same geometry from the video, atom for atom.
// - Don't waste time copying source code into the video. The primary objective
//   is to test the new MM4ForceField API.

enum RobotVideo {
  // Two-finger robot arm with a rectangular frame.
  case version1
  
  // Three-finger robot arm with a hexagonal frame.
  case version2
}
