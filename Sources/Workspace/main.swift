import HDL
import MolecularRenderer
import Numerics

let quaternion = Quaternion<Float>(
  angle: 1, axis: SIMD3(0, 0, 1))
print(quaternion.act(on: SIMD3(1, 0, 0)))

let lattice = Lattice<Hexagonal> { h, k, l in
  let h2k = h + 2 * k
  Bounds { 10 * h + 8 * h2k + 8 * l }
  Material { .checkerboard(.silicon, .carbon) }
}
print(lattice.atoms.count)

var reconstruction = Reconstruction()
reconstruction.topology.insert(atoms: lattice.atoms)
reconstruction.material = .checkerboard(.silicon, .carbon)
reconstruction.compile()
let topology = reconstruction.topology
print(topology.atoms.count)
