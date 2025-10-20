import HDL
import MolecularRenderer

// Remaining tasks of this PR:
// - Work on setting up the large scene test.
//   - Prepare compiled structures
//   - Measure the largest spatial distance of any atom from the lattice's
//     center, then prepare a conservative bounding box for the two cases.
//   - Dry run the loading process. A cube almost at the world's dimension
//     limits, and a hollow sphere inside with a specified radius. Both the
//     cube side length and sphere radius are specified independently.
//   - Find a good data distribution between world limit, percentage of
//     interior volume open to viewing, and atom count.
