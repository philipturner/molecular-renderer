// Tasks:
// - Flesh out the notion of transactions (.add, .remove, .move, none) and
//   how they materialize on the CPU-side API.
// - Create GPU code to simply compile the transactions into a linear list of
//   atoms as the "acceleration structure" for now.
// - Create a simple test that switches between isopropanol and methane to
//   demonstrate correct functioning of .add and .remove.
//
// First concept: allocating fixed "address space" for atoms at startup
// Second concept: the CPU-side API for entering / modifying atoms
// Third concept: making this CPU-side API computationally efficient
