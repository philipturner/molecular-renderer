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
  
  // Track the remaining atoms to ensure the numbers add up 100%.
  // TODO: As a proof of correctness, check the atom count calculated for the
  // servo arm gripper against the statistics here.
  var miscellaneousAtomCount = 0 // catalysts and products
  
  // MARK: - Gather Statistics
  
  var atoms: [Media.Crystolecule: Int] = [:]
  var instances: [Media.Crystolecule: Int] = [:]
  for key in Media.Crystolecule.allCases {
    instances[key] = 0
  }
  
  do {
    let beltLinkLattice = createBeltLink()
    let beltLink = Diamondoid(lattice: beltLinkLattice)
    atoms[.beltLink] = beltLink.atoms.count
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
    
    // The final belt link structure has atoms not in the crystolecule.
    for beltLink in quadrant.beltLinks {
      let extraAtoms = beltLink.atoms.count - atoms[.beltLink]!
      precondition(extraAtoms > 0, "Unexpected atom count.")
      miscellaneousAtomCount += extraAtoms
      instances[.beltLink]! += 1
    }
  }
  
  // MARK: - Report Statistics
  
  struct TableEntry {
    var part: String
    var atomCount: String
    var instanceCount: String
  }
  var table: [TableEntry] = []
  table.append(
    TableEntry(
      part: "Part", atomCount: "Atom Count", instanceCount: "Part Count"))
  
  for crystolecule in Media.Crystolecule.allCases {
    let entry = TableEntry(
      part: crystolecule.description,
      atomCount: "\(atoms[crystolecule] ?? 0)",
      instanceCount: "\(instances[crystolecule]!)")
    table.append(entry)
  }
  let partEntriesEnd = table.count
  table.append(
    TableEntry(
      part: "Catalysts & Products",
      atomCount: "\(miscellaneousAtomCount)",
      instanceCount: "n/a"))
  
  // Gather Statistics
  do {
    var compiledAtoms: Int = 0
    var compiledParts: Int = 0
//    var
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
  
  func printEntry(_ entry: TableEntry) {
    let part = pad(entry.part, size: columnSize[0])
    let atomCount = pad(entry.atomCount, size: columnSize[1])
    let instanceCount = pad(entry.instanceCount, size: columnSize[2])
    print(part + " | " + atomCount + " | " + instanceCount)
  }
  func dividerSection() -> String {
    String(repeating: "-", count: columnSize[0]) + " | " +
    String(repeating: "-", count: columnSize[1]) + " | " +
    String(repeating: "-", count: columnSize[2])
  }
  
  print()
  print(pad("Bill of Materials", size: dividerSection().count))
  print()
  printEntry(table[0])
  print(dividerSection())
  for entry in table[1..<partEntriesEnd] {
    printEntry(entry)
  }
  print(dividerSection())
  for summary in table[partEntriesEnd...] {
    printEntry(summary)
  }
  print()
  
  fatalError("Returning early.")
//  return scene.createAtoms()
}
