import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Fire up the old AFM probe embedded into the hardware catalog and/or
// the HDL unit tests. Design a good tooltip and set up a scripting environment
// for tripod build sequences.
// - Silicon probe, but (H3C)3-Ge* tooltip.
// - Create a build sequence compiler using the known set of reactions, after
//   this environment is set up. Pretend the germanium atoms are actually C.
// - 8885 atoms, estimated 50,000 tripods

func createGeometry() -> [Entity] {
  var tripod = Tripod()
  
  var germanium: Entity?
    for atom in tripod.topology.atoms {
      if atom.atomicNumber == 32 {
        germanium = atom
      }
    }
    guard let germanium else {
      fatalError("Could not find germanium.")
    }
    
    // Add the feedstock to the tripod (hasty solution).
    do {
      var position = germanium.position
      position.y += Element.germanium.covalentRadius
      position.y += Element.carbon.covalentRadius
      let carbon = Entity(position: position, type: .atom(.carbon))
      let carbonID = tripod.topology.atoms.count
      
      var insertedAtoms = [carbon]
      var insertedBonds: [SIMD2<UInt32>] = []
      for passivatorID in 0..<3 {
        var element: Element
        if passivatorID == 0 {
          element = .hydrogen
        } else {
          element = .bromine
        }
        
        let baseAngle: Float = 109.47 * .pi / 180
        let baseRotation = Quaternion(angle: baseAngle, axis: [0, 0, 1])
        let secondAngle = Float(passivatorID) * .pi * 2 / 3
        let secondRotation = Quaternion(angle: secondAngle, axis: [0, 1, 0])
        
        var orbital: SIMD3<Float> = .init(0, -1, 0)
        orbital = baseRotation.act(on: orbital)
        orbital = secondRotation.act(on: orbital)
        
        var bondLength: Float = .zero
        bondLength += Element.carbon.covalentRadius
        bondLength += element.covalentRadius
        let position = carbon.position + bondLength * orbital
        let passivator = Entity(position: position, type: .atom(element))
        
        let passivatorID = tripod.topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(carbonID), UInt32(passivatorID))
        insertedAtoms.append(passivator)
        insertedBonds.append(bond)
      }
      tripod.topology.insert(atoms: insertedAtoms)
      tripod.topology.insert(bonds: insertedBonds)
    }
  
  // Set the silyl group as anchors.
  var anchors: [Int] = []
  for atomID in tripod.topology.atoms.indices {
    let atom = tripod.topology.atoms[atomID]
    if atom.atomicNumber == 14 || atom.position.y < 0 {
      anchors.append(atomID)
    }
  }
  
  // Solve for the geometry.
  var solver = XTBSolver(cpuID: 0)
  solver.atoms = tripod.topology.atoms
  solver.process.anchors = anchors
  solver.solve(arguments: ["--opt"])
  solver.load()
  tripod.topology.atoms = solver.atoms
  
  return tripod.topology.atoms
}
