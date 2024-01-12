//
//  RobotPartPlacement.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/10/24.
//

import MM4

// Reproduce Tom Moore's nano-robot part placement, export to a video.
// - Litmus test of the new MM4ForceField implementation
// - Experiment with new production rendering/simulation workflows.
//
// Details:
// - Reproduce the video subtitles.
//   - MD Package: MM4
//   - Level of Theory: Molecular Dynamics
//   - Atoms: 7,242 (10000.0 ms compile time)
//   - Rendered with Apple Metal
// - Copy the exact same geometry from the video, atom for atom.
// - There will be 2+ videos. Only reproduce the first video for now. It's less
//   work to design the geometry; less complex code to script together. That
//   allows you to reproduce the remaining videos in order, in the future.

enum RobotVideo {
  // Two-finger robot arm with a rectangular frame.
  case version1
  
  // Three-finger robot arm with a hexagonal frame.
  case version2
}
