//
//  ExampleProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/17/23.
//

import Foundation
import MolecularRenderer

struct ExampleProviders {
  static func taggedEthylene(
    styleProvider: MRStaticStyleProvider
  ) -> MRStaticAtomProvider {
    ExampleMolecules.TaggedEthylene(styleProvider: styleProvider)
  }
  
  static func planetaryGearBox(
    styleProvider: MRStaticStyleProvider
  ) -> MRStaticAtomProvider {
    NanoEngineerParser(
      styleProvider: styleProvider,
      partLibPath: "gears/MarkIII[k] Planetary Gear Box")
  }
  
  static func adamantaneHabTool(
    styleProvider: MRStaticStyleProvider
  ) -> MRStaticAtomProvider {
    // NOTE: You need to give the app permission to view this file.
    let adamantaneHabToolURL: URL = {
      let fileName = "adamantane-thiol-Hab-tool.pdb"
      let folder = "/Users/philipturner/Documents/OpenMM/Renders/Imports"
      return URL(filePath: folder + "/" + fileName)
    }()
    return PDBParser(styleProvider: styleProvider, url: adamantaneHabToolURL)
  }
}
