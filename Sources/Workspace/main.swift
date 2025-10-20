import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Implement the critical pixel count test; shouldn't take much time.
//   - Move the camera into the basis of the lattice, instead of the other
//     way around.
//   - Inspect the diamond and GaAs structures after compiling, to see the
//     cleaned up surfaces.
//   - Use a common lattice dimension for all structures. Start with a small
//     number, then scale it when other components of the test are working.
// - Clean up the documentation and implement the remaining tests.

#if false
// Drafting the (111) basis vectors.
let basisX = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
let basisY = SIMD3<Float>(-1, 2, -1) / Float(6).squareRoot()
let basisZ = SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
print((basisX * basisX).sum())
print((basisY * basisY).sum())
print((basisZ * basisZ).sum())
print((basisX * basisY).sum())
print((basisY * basisZ).sum())
print((basisZ * basisX).sum())
#endif

#if false
// Drafting the (110) basis vectors.
let basisX = SIMD3<Float>(1, 0, 0) / Float(1).squareRoot()
let basisY = SIMD3<Float>(0, 1, -1) / Float(2).squareRoot()
let basisZ = SIMD3<Float>(0, 1, 1) / Float(2).squareRoot()
print((basisX * basisX).sum())
print((basisY * basisY).sum())
print((basisZ * basisZ).sum())
print((basisX * basisY).sum())
print((basisY * basisZ).sum())
print((basisZ * basisX).sum())
#endif
