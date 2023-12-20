//
//  Utilities.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation

#if arch(arm64)

#else
// x86_64 is not supported; we are just bypassing a compiler error.
public typealias Float16 = UInt16
#endif
