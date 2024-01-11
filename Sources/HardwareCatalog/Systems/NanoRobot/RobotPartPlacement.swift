//
//  RobotPartPlacement.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/10/24.
//

import MM4

// Reproduce Tom Moore's nano-robot part placement, export to a video.
// - Litmus test of the new MM4ForceField implementation
// - Experiment with new video creation workflows
//   - No serialization, if simulation latency is short enough.
//   - iPhone recording to show real-time FPS monitor.
//
// Details:
// - Reproduce the video subtitles.
//   - MD Package: OpenMM
//   - FF: MM4
//   - Atoms: 7,242 (10.0 ms compile time)
//   - Rendered with Apple Metal
// - Copy the exact same geometry from the video, atom for atom.
// - There will be 2+ videos. Only reproduce the first video for now. It's less
//   work to design the geometry; less complex code to script together. That
//   allows you to reproduce the remaining videos in order, in the future.
//
// Structure:
// - Small section of code on top left, the highest-level entry function.
// - Subtitles on bottom left - print the subtitles through console output.
//   - Put the Xcode window next to the MRApp window, removing the need for
//     any video post-processing.
// - iPhone video on right, cropped to a square w/ rounded corners.

enum RobotVideo {
  // Two-finger robot arm with a rectangular frame.
  case version1
  
  // Three-finger robot arm with a hexagonal frame.
  case version2
}
