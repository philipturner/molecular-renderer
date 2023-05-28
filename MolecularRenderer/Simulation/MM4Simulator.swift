//
//  MM4Simulator.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 5/6/23.
//

import Foundation
import simd

// Synchronous GPU simulator evolved from the Drexler-MM2 forcefield from
// Nanosystems (1992). Only applies to sp3 hydrocarbons, but achieves hundreds
// of ps/s. Eventually it can be extended to a few more elements.
