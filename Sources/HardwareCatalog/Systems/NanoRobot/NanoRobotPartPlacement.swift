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
// - Show all the source code at the end of the video.
//   - Somewhere in the code, comment that the temperature is 0 Kelvin.
//     Show the array of zero velocities being created.
