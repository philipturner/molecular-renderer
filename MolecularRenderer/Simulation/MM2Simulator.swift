//
//  MM2Simulator.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/6/23.
//

import Foundation
import simd

// Reproduces the Drexler-MM2 forcefield from Nanosystems (1992). Multi-core CPU
// simulator that supports complex forces, FP32, and runs asynchronously.
// Fastest existing simulator for 1-1000 atoms; use OpenMM for 1K-1M atoms.
