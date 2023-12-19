// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

// TODO: Move this scratch into the hardware catalog instead of a
// GitHub gist. Name the folder "ConvergentAssemblyArchitecture".
// - Add thumbnail to folder once the film is released.
// - Also add poster cataloguing the crystolecules.

func createNanomachinery() -> [MRAtom] {
  let scene = FactoryScene()
  
  // MARK: - Gather Statistics
  
  var atoms: [Media.Crystolecule: Int] = [:]
  var instances: [Media.Crystolecule: Int] = [:]
  for key in Media.Crystolecule.allCases {
    instances[key] = 0
  }
  
  for quadrant in scene.quadrants {
    var minBoardSize: Int = .max
    var maxBoardSize: Int = .min
    for backBoard in quadrant.backBoards {
      minBoardSize = min(minBoardSize, backBoard.atoms.count)
      maxBoardSize = max(maxBoardSize, backBoard.atoms.count)
    }
    atoms[.backBoard1] = maxBoardSize
    atoms[.backBoard2] = minBoardSize
    for backBoard in quadrant.backBoards {
      if backBoard.atoms.count == maxBoardSize {
        instances[.backBoard1]! += 1
      } else if backBoard.atoms.count == minBoardSize {
        instances[.backBoard2]! += 1
      } else {
        fatalError("Unexpected board size.")
      }
    }
  }
  
  // MARK: - Report Statistics
  
  // TODO: Transition this code to "Scratch5" before adding data for more parts.
  // This will reduce Swift compile times when the amount of code gets large.
  
  struct TableEntry {
    var part: String
    var atomCount: String
    var instanceCount: String
  }
  var table: [TableEntry] = []
  table.append(
    TableEntry(
      part: "Part", atomCount: "Atom Count", instanceCount: "Instance Count"))
  
  for crystolecule in Media.Crystolecule.allCases {
    let entry = TableEntry(
      part: crystolecule.description,
      atomCount: "\(atoms[crystolecule]!)",
      instanceCount: "\(instances[crystolecule]!)")
    table.append(entry)
  }
  
  var columnSize: SIMD3<Int> = .zero
  for entry in table {
    let size = SIMD3(entry.part.count,
                     entry.atomCount.count,
                     entry.instanceCount.count)
    columnSize.replace(with: size, where: size .> columnSize)
  }
  func pad(_ string: String, size: Int) -> String {
    let missing = size - string.count
    let left = String(repeating: " ", count: missing / 2)
    let right = String(repeating: " ", count: missing - left.count)
    return left + string + right
  }
  
  fatalError("No output.")
}
