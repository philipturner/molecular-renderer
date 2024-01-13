//
//  RobotPartPlacement.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/10/24.
//

import HDL
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

func createNanoRobot() -> [[Entity]] {
  // Video structure:
  // - looking at workspace
  //   - screenshot from YouTube video behing Xcode window
  // - video the entire scene compiling in 15 seconds
  //   - zoom in on the compile time
  // - video the window on the MacBook
  // - after the animation is done, move around in the scene
  let robotFrame = RobotFrame()
  return robotFrame.animationFrames
}

/*
 let start = CACurrentMediaTime()
 let frames = createNanoRobot()
 let end = CACurrentMediaTime()
 print("animation_seconds=\(Double(frames.count) / 120)")
 
 let separator = String(repeating: "=", count: 40)
 let timeRepr = String(format: "%.3f", (end - start) * 1e0)
 print()
 print(separator)
 print("     MD Package: MM4")
 print("Level of Theory: Molecular Dynamics")
 print("          Atoms: \(frames.reduce(0) { max($0, $1.count) })")
 print("   Compile Time: \(timeRepr) s")
 print("    Rendered with Apple Metal")
 print(separator)
 
 usleep(3_000_000)
 renderingEngine.setAtomProvider(AnimationAtomProvider(frames.map {
   $0.map(MRAtom.init)
 }))
 */
