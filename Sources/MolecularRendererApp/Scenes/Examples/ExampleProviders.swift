//
//  ExampleProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/17/23.
//

import Foundation
import MolecularRenderer

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
}
