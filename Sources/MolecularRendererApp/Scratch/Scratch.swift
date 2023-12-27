// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

func createReconstructionDemo() -> [MRAtom] {
  let lattice = createBeamLattice()
  var topology = Topology()
  topology.insert(atoms: lattice)
  
  var reconstruction = Reconstruction()
  reconstruction.topology = topology
  reconstruction.prepare()
  reconstruction.apply()
  topology = reconstruction.topology
  
  return topology.atoms.map(MRAtom.init)
}

struct Reconstruction {
  var topology: Topology = Topology()
  var initialTypes: [MM4CenterType] = []
  
  // These lists must always be sorted.
  var hydrogensToAtomsMap: [[UInt32]] = []
  var atomsToHydrogensMap: [[UInt32]] = []
  
  // There should be some method for the user to specify how 2-way and 3-way
  // collisions were resolved.
  // ->
  // Perhaps a piece of data post-application that can be used to nudge atoms
  // into a position of lower energy. Or the nudges are applied during apply().
  // ->
  // If any structures have 4-way collisions, we'll need to automatically patch
  // them. Otherwise, just crash because they don't fit into the rule system.
  
  // TODO: Act as a proxy intercepting remove() and bond reassignment operations
  // on the topology, enabling the generation of fully enclosed rings. Although
  // they may not be manufacturable, they are helpful for some analyses. They
  // might be easy-to-design surrogates for multi-part shell structures.
  
  mutating func prepare() {
    removePathologialAtoms()
    createBulkAtomBonds()
    createHydrogenSites()
  }
  
  mutating func apply() {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    func createCenter(_ atomList: [Int]) -> SIMD3<Float>? {
      guard atomList.count > 1 else {
        return nil
      }
      var output: SIMD3<Float> = .zero
      for atomID in atomList {
        let atom = topology.atoms[atomID]
        output += atom.position
      }
      output /= Float(atomList.count)
      return output
    }
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    for atomList in hydrogensToAtomsMap {
      if atomList.count == 0 {
        // This collision was resolved.
        continue
      }
      if atomList.count == 1 {
        let atomID = Int(atomList[0])
        let hydrogenList = atomsToHydrogensMap[atomID]
        let orbital = orbitals[atomID]
        precondition(orbital.count > 0, "No orbitals.")
        
        // If 1 orbital has a collision:
        //
        // Use a scoring function to match collision(s) to orbitals.
        
        // If there are 2 orbitals and both are collision-free:
        //
        // The compiler uses a deterministic method to generate orbitals. Plus,
        // the orbitals are already generated once. Assign the first hydrogen
        // in the list to the first orbital.
      }
      if atomList.count == 2 {
        // We will eventually drop the hydrogens straight in, then nudge them
        // into an energy-minimized position. For now, simply append helium and
        // don't connect to any carbons. The position looks a bit wierd because
        // it isn't using orbitals.
      }
      if atomList.count > 2 {
        fatalError("Hydrogen sites with >2 hydrogens are not recognized yet.")
      }
    }
    topology.insert(atoms: insertedAtoms)
  }
}
