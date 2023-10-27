//
//  ExampleProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/17/23.
//

import Foundation
import MolecularRenderer
import HDL

struct ExampleProviders {
  static func planetaryGearBox() -> NanoEngineerParser {
    NanoEngineerParser(
      partLibPath: "gears/MarkIII[k] Planetary Gear Box")
  }
  
  static func adamantaneHabTool() -> PDBParser {
    let adamantaneHabToolURL: URL = {
      return URL(string: "https://gist.githubusercontent.com/philipturner/6405518fadaf902492b1498b5d50e170/raw/d660f82a0d6bc5c84c0ec1cdd3ff9140cd7fa9f2/adamantane-thiol-Hab-tool.pdb")!
    }()
    return PDBParser(url: adamantaneHabToolURL, hasA1: true)
  }
  
  static func fineMotionController() -> NanoEngineerParser {
    NanoEngineerParser(
      partLibPath: "others/Fine Motion Controller")
  }
  
  // https://raw.githubusercontent.com/eudoxia0/MNT/master/gears/nanotube-worm-drive.mmp
  // https://raw.githubusercontent.com/eudoxia0/MNT/master/transport/fullerene-conveyor-cart.mmp
  // https://raw.githubusercontent.com/eudoxia0/MNT/master/transport/gantry.mmp
  
  //    self.atomProvider = PlanetaryGearBox()
  //    self.atomProvider = APMBootstrapper()
  //    self.atomProvider = ExampleProviders.fineMotionController()
  //    self.atomProvider = MassiveDiamond(outerSize: 100, thickness: 2)
  
  static func carbidesComparison() -> ArrayAtomProvider {
    let spacingX: Float = 5
    let spacingZ: Float = 8
    
    let latticeC = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * (h + h2k + l) }
      Material { .elemental(.carbon) }
    }
    var atoms = latticeC.entities.map(MRAtom.init)
    
    atoms += latticeC.entities.map(MRAtom.init).map {
      var copy = $0
      copy.origin.z += -spacingZ
      return copy
    }
    
    let latticeSi = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * (h + h2k + l) }
      Material { .elemental(.silicon) }
    }
    atoms += latticeSi.entities.map(MRAtom.init).map {
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
    atoms += latticeGe.entities.map(MRAtom.init).map {
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
    atoms += latticeCSi.entities.map(MRAtom.init).map {
      var copy = $0
      copy.origin.x += spacingX
      return copy
    }
    
    let latticeCGe = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * (h + h2k + l) }
      Material { .checkerboard(.carbon, .germanium) }
    }
    atoms += latticeCGe.entities.map(MRAtom.init).map {
      var copy = $0
      copy.origin.x += 2 * spacingX
      return copy
    }
    
    return ArrayAtomProvider(atoms)
  }
}
