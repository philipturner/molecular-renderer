//
//  MM4Forces+Nonbonded.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/8/23.
//

import Foundation

// vdW force, for now, not segregating the atoms into two different groups
// - Still rearranging indices, just using perfect order reversal as P.O.C.
// Electrostatic force, using an interaction group to mask out neutral atoms
