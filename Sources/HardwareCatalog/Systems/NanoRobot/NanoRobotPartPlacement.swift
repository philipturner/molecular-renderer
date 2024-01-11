//
//  NanoRobotPartPlacement.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/10/24.
//

import Foundation

// Reproduce Tom Moore's nano-robot part placement, export to a video.
// - Litmus test of the new MM4ForceField implementation
// - Experiment with new serialization/video exporting workflows
//
// Details:
// - Reproduce the video subtitles.
//   - MD Package: OpenMM
//   - FF: MM4
//   - 13,054 Atoms, 10.0 ms Compile Time
//   - Rendered with Apple Metal
// - Copy the exact same geometry from the video, atom for atom.
