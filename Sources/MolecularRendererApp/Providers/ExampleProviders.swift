//
//  ExampleProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/17/23.
//

import Foundation
import MolecularRenderer

struct ExampleProviders {
  static func taggedEthylene() -> MRStaticAtomProvider {
    ExampleMolecules.TaggedEthylene()
  }
  
  static func planetaryGearBox() -> MRStaticAtomProvider {
    NanoEngineerParser(partLibPath: "gears/MarkIII[k] Planetary Gear Box")
  }
  
  static func adamantaneHabTool() -> MRStaticAtomProvider {
    let adamantaneHabToolURL: URL = {
      let fileName = "adamantane-thiol-Hab-tool.pdb"
      let folder = "/Users/philipturner/Documents/OpenMM/Renders/Imports"
      return URL(filePath: folder + "/" + fileName)
    }()
    return PDBParser(url: adamantaneHabToolURL)
  }
}
