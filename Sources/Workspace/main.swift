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

// Utility function for creating a random rotational basis, without relying on
// quaternions.
//
// Named 'RotationBasis' to avoid a name conflict with 'Basis' from the HDL
// library and not worry about potential issues.
typealias RotationBasis = (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
func createRandomRotation() -> RotationBasis {
  func createRandomDirection() -> SIMD3<Float> {
    for _ in 0..<100 {
      var output = SIMD3<Float>.random(in: -1...1)
      let length = (output * output).sum().squareRoot()
      if length > 1 || length < 0.001 {
        continue
      }
      
      output /= length
      return output
    }
    fatalError("Algorithm failed to converge.")
  }
  
  func cross(
    _ lhs: SIMD3<Float>,
    _ rhs: SIMD3<Float>
  ) -> SIMD3<Float> {
    let yzx = SIMD3<Int>(1, 2, 0)
    let zxy = SIMD3<Int>(2, 0, 1)
    return (lhs[yzx] * rhs[zxy]) - (lhs[zxy] * rhs[yzx])
  }
  
  let random1 = createRandomDirection()
  let random2 = createRandomDirection()
  
  var cross12 = cross(random1, random2)
  let cross12Length = (cross12 * cross12).sum().squareRoot()
  if cross12Length < 0.001 || cross12Length > 1 {
    fatalError("Could not take cross product.")
  }
  cross12 /= cross12Length
  
  let xAxis = random1
  let yAxis = cross12
  let zAxis = cross(xAxis, yAxis)
  
  return (xAxis, yAxis, zAxis)
}

// Task: rotate a topology, analyze the spatial extent, and confirm it looks
// sensible by rendering it.
