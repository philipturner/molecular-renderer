//
//  AsyncSimulator.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/9/23.
//

import Foundation

// Asynchronous background process that calls into synchronous simulators, such
// as NobleGasSimulator or no-cutoff OpenMM GPU. Designed to minimize the chance
// that OpenCL work corrupts Metal Frame Capture. Works best at under 5,000
// timesteps/second and under 5,000 atoms.
