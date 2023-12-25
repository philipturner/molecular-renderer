//
//  Carbides.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/24/23.
//

import Foundation

#if false

func carbidesComparison() -> ArrayAtomProvider {
  let spacingX: Float = 5
  let spacingZ: Float = 8
  
  let latticeC = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * (h + h2k + l) }
    Material { .elemental(.carbon) }
  }
  var atoms = latticeC.atoms.map(MRAtom.init)
  
  atoms += latticeC.atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.z += -spacingZ
    return copy
  }
  
  let latticeSi = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * (h + h2k + l) }
    Material { .elemental(.silicon) }
  }
  atoms += latticeSi.atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += spacingX
    copy.origin.z += -spacingZ
    return copy
  }
  
  let latticeGe = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * (h + h2k + l) }
    Material { .elemental(.germanium) }
  }
  atoms += latticeGe.atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 2 * spacingX
    copy.origin.z += -spacingZ
    return copy
  }
  
  let latticeCSi = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * (h + h2k + l) }
    Material { .checkerboard(.carbon, .silicon) }
  }
  atoms += latticeCSi.atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += spacingX
    return copy
  }
  
  let latticeCGe = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * (h + h2k + l) }
    Material { .checkerboard(.carbon, .germanium) }
  }
  atoms += latticeCGe.atoms.map(MRAtom.init).map {
    var copy = $0
    copy.origin.x += 2 * spacingX
    return copy
  }
  
  return ArrayAtomProvider(atoms)
}

#endif
