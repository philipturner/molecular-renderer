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
    for broadcastRod in quadrant.broadcastRods {
      atoms[.broadcastRod] = broadcastRod.atoms.count
      instances[.broadcastRod]! += 1
    }
    
    for assemblyLine in quadrant.assemblyLines {
      atoms[.geHousing] = assemblyLine.housing.atoms.count
      instances[.geHousing]! += 1
    }
    
    // Add the contribution from the spacer housing.
    precondition(quadrant.spacerHousing.atoms.count == atoms[.geHousing]!)
    instances[.geHousing]! += 1
  }
  
  for hexagon in scene.floor!.hexagons {
    atoms[.floorHexagon] = hexagon.atoms.count
    instances[.floorHexagon]! += 1
  }
  
  // MARK: - Report Statistics
  
  func formatNumber(_ number: Int) -> String {
    precondition(number >= 0)
    if number == 0 {
      return "0"
    }
    
    var chunks: [String] = []
    var result = number
    while result > 0 {
      chunks.append("\(result % 1000)")
      result /= 1000
    }
    return chunks.reversed().joined(separator: ",")
  }
  
  struct TableEntry {
    var part: String
    var atomCount: String
    var instanceCount: String
    var atomPercent: String = ""
  }
  var table: [TableEntry] = []
  table.append(
    TableEntry(
      part: "Part",
      atomCount: "Atom Count",
      instanceCount: "Part Count",
      atomPercent: "Atom %"))
  
  for crystolecule in Media.Crystolecule.allCases {
    let entry = TableEntry(
      part: crystolecule.description,
      atomCount: formatNumber(atoms[crystolecule] ?? 0),
      instanceCount: formatNumber(instances[crystolecule]!))
    table.append(entry)
  }
  let partEntriesEnd = table.count
  
  // Gather Statistics
  var totalAtoms: Int = 0
  do {
    var compiledAtoms: Int = 0
    var compiledParts: Int = 0
    var instantiatedAtoms: Int = 0
    var instantiatedParts: Int = 0
    for crystolecule in Media.Crystolecule.allCases {
      let thisAtoms = atoms[crystolecule] ?? 0
      let thisInstances = instances[crystolecule]!
      compiledAtoms += thisAtoms
      compiledParts += 1
      instantiatedAtoms += thisAtoms * thisInstances
      instantiatedParts += thisInstances
    }
    table.append(
      TableEntry(
        part: "Compiled",
        atomCount: formatNumber(compiledAtoms),
        instanceCount: formatNumber(compiledParts)))
    table.append(
      TableEntry(
        part: "Instantiated",
        atomCount: formatNumber(instantiatedAtoms),
        instanceCount: formatNumber(instantiatedParts)))
    table.append(
      TableEntry(
        part: "Catalysts & Products",
        atomCount: formatNumber(miscellaneousAtomCount),
        instanceCount: "n/a"))
    
    totalAtoms = instantiatedAtoms + miscellaneousAtomCount
    table.append(
      TableEntry(
        part: "Total",
        atomCount: formatNumber(totalAtoms),
        instanceCount: formatNumber(instantiatedParts)))
    
    let propCompiled = Double(compiledAtoms) / Double(totalAtoms)
    let propInstanced = Double(instantiatedAtoms) / Double(totalAtoms)
    let propMisc = Double(miscellaneousAtomCount) / Double(totalAtoms)
    table[table.count - 4].atomPercent =
    String(format: "%.1f", 100 * propCompiled) + "%"
    table[table.count - 3].atomPercent =
    String(format: "%.1f", 100 * propInstanced) + "%"
    table[table.count - 2].atomPercent =
    String(format: "%.1f", 100 * propMisc) + "%"
    table[table.count - 1].atomPercent = "100.0%"
  }
  
  for entryID in 1..<partEntriesEnd {
    let thisAtoms = table[entryID].atomCount.filter { $0 != "," }
    let thisInstances = table[entryID].instanceCount.filter { $0 != "," }
    let proportion =
    Double(thisAtoms)! * Double(thisInstances)! / Double(totalAtoms)
    table[entryID].atomPercent =
    String(format: "%.1f", 100 * proportion) + "%"
  }
  
  var columnSize: SIMD4<Int> = .zero
  for entry in table {
    let size = SIMD4(entry.part.count,
                     entry.atomCount.count,
                     entry.instanceCount.count,
                     entry.atomPercent.count)
    columnSize.replace(with: size, where: size .> columnSize)
  }
  func pad(
    _ string: String, size: Int,
    alignLeft: Bool = false, alignRight: Bool = false
  ) -> String {
    let missing = size - string.count
    if alignLeft {
      return string + String(repeating: " ", count: missing)
    }
    if alignRight {
      return String(repeating: " ", count: missing) + string
    }
    let left = String(repeating: " ", count: missing / 2)
    let right = String(repeating: " ", count: missing - left.count)
    return left + string + right
  }
  
  func entryRepr(
    _ entry: TableEntry, alignLeft: Bool = false, alignRight: Bool = false
  ) -> String {
    let part = pad(
      entry.part, size: columnSize[0], alignLeft: alignLeft)
    let atomCount = pad(
      entry.atomCount, size: columnSize[1], alignRight: alignRight)
    let instanceCount = pad(
      entry.instanceCount, size: columnSize[2], alignRight: alignRight)
    let atomPercent = pad(
      entry.atomPercent, size: columnSize[3], alignRight: alignRight)
    
    var output: String = ""
    output += part + " | "
    output += atomCount + " | "
    output += instanceCount + " | "
    output += atomPercent
    return output
  }
  func dividerSection() -> String {
    String(repeating: "-", count: columnSize[0]) + " | " +
    String(repeating: "-", count: columnSize[1]) + " | " +
    String(repeating: "-", count: columnSize[2]) + " | " +
    String(repeating: "-", count: columnSize[3])
  }
  
  print()
  print(pad("Bill of Materials", size: dividerSection().count))
  print()
  print(entryRepr(table[0]))
  print(dividerSection())
  for entry in table[1..<partEntriesEnd] {
    print(entryRepr(entry, alignLeft: true, alignRight: true))
  }
  print(dividerSection())
  for summary in table[partEntriesEnd...] {
    print(entryRepr(summary, alignRight: true))
  }
  print()
  
//  print("Returning early.")
  exit(0)
//  return scene.createAtoms()
}
