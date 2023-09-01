//
//  MM4.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/30/23.
//

import Foundation
import QuaternionModule

// Carry over information from 'Lattice' in the hardware description lattice,
// so each movable chunk has its momentum conserved (some may be connected by
// double or triple-bonded carbons). In addition, conserve momentum of each
// cluster of adjacent lattice cells.
