import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Work on setting up the large scene test.
//   - Create a method for generating a random rotational basis.
//   - Dry run the loading process. A cube almost at the world's dimension
//     limits, and a hollow sphere inside with a specified radius. Both the
//     cube side length and sphere radius are specified independently.
//   - Find a good data distribution between world limit, percentage of
//     interior volume open to viewing, and atom count.

// MARK: - Compile Structure

let latticeSize: Float = 23
let worldDimension: Float = 384
let isDenselyPacked: Bool = false

func passivate(topology: inout Topology) {
  func createHydrogen(
    atomID: UInt32,
    orbital: SIMD3<Float>
  ) -> Atom {
    let atom = topology.atoms[Int(atomID)]
    
    var bondLength = atom.element.covalentRadius
    bondLength += Element.hydrogen.covalentRadius
    
    let position = atom.position + bondLength * orbital
    return Atom(position: position, element: .hydrogen)
  }
  
  let orbitalLists = topology.nonbondingOrbitals()
  
  var insertedAtoms: [Atom] = []
  var insertedBonds: [SIMD2<UInt32>] = []
  for atomID in topology.atoms.indices {
    let orbitalList = orbitalLists[atomID]
    for orbital in orbitalList {
      let hydrogen = createHydrogen(
        atomID: UInt32(atomID),
        orbital: orbital)
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      insertedAtoms.append(hydrogen)
      
      let bond = SIMD2(
        UInt32(atomID),
        UInt32(hydrogenID))
      insertedBonds.append(bond)
    }
  }
  topology.atoms += insertedAtoms
  topology.bonds += insertedBonds
}

func analyze(topology: Topology) {
  print()
  print("atom count:", topology.atoms.count)
  do {
    var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    for atom in topology.atoms {
      let position = atom.position
      minimum.replace(with: position, where: position .< minimum)
      maximum.replace(with: position, where: position .> maximum)
    }
    print("minimum:", minimum)
    print("maximum:", maximum)
  }
}

func createTopology() -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { latticeSize * (h + k + l) }
    
    // Invert the atom ordering from previous tests in this repo. Now the
    // silicon atoms are shown on the surface. It's more ugly, but expands the
    // test coverage.
    Material { .checkerboard(.silicon, .carbon) }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.atoms = lattice.atoms
  reconstruction.material = .checkerboard(.silicon, .carbon)
  var topology = reconstruction.compile()
  passivate(topology: &topology)
  
  // Shift the structure so it's centered at the origin.
  let latticeConstant = Constant(.square) {
    .checkerboard(.silicon, .carbon)
  }
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    
    let deltaMagnitude = latticeSize * latticeConstant / 2
    atom.position -= SIMD3(repeating: deltaMagnitude)
    
    topology.atoms[atomID] = atom
  }
  
  return topology
}

let topology = createTopology()
analyze(topology: topology)

// MARK: - Scene Construction

// Since the lattice is already centered, we don't have to perform a reduction
// over all the atoms beforehand, just to establish the min/max/center point.
func getRadialExtent(topology: Topology) -> Float {
  var radialExtent: Float = .zero
  for atom in topology.atoms {
    let position = atom.position
    let distance = (position * position).sum().squareRoot()
    radialExtent = max(radialExtent, distance)
  }
  return radialExtent
}
func getCartesianExtent(topology: Topology) -> Float {
  var cartesianExtent: Float = .zero
  for atom in topology.atoms {
    let position = atom.position
    let distance = position[0].magnitude
    cartesianExtent = max(cartesianExtent, distance)
  }
  return cartesianExtent
}
print("radial extent:", getRadialExtent(topology: topology))
print("cartesian extent:", getCartesianExtent(topology: topology))

// Add 0.5 nm of padding on both sides of the object, to create the spacing
// between objects.
func getSafeSpacing(topology: Topology) -> Float {
  var extent: Float
  if isDenselyPacked {
    extent = getCartesianExtent(topology: topology)
  } else {
    extent = getRadialExtent(topology: topology)
  }
  extent += 0.5
  
  return 2 * extent
}
print("safe spacing:", getSafeSpacing(topology: topology))
