import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Compile an axle, and a sheet of diamond that will curl around it.
  let sheetLattice = SheetPart.createLattice()
  let axleLattice = AxlePart.createLattice()
  
  var atoms: [Entity] = []
  atoms.append(contentsOf: sheetLattice.atoms)
  atoms.append(contentsOf: axleLattice.atoms)
  return atoms
}

