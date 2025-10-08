import Foundation
import MolecularRenderer

// Specification of near-term goal:
// - No use of Metal or DirectX profilers
// - No tracing of AO rays
// - No incremental updates
// - GPU receives compact list of atoms and motion vectors from CPU,
//   address space O(100,000)
// - No optimizations to memory layout or ray tracing
// - No compaction of the static large voxels into dynamic large voxels
//
// Specification of end state for this PR:
// - Skipping past unoccupied large voxels in primary ray intersector, using
//   almost identical code to main-branch-backup
// - Use the simplest "early stages" memory design, except that 8x duplicated
//   per-atom offsets of global -> 2 nm will use 16-bit integers. By not
//   over-optimizing the ray-sphere intersections or small cells building
//   kernel, I reduce the need to inspect Metal or DirectX profilers.
// - Include incremental acceleration structure updates
// - Include the "idle" vs "active" paradigm for handling motion vectors
// - Fix any possible CPU-side bottlenecks when uploading many atoms per frame
// - No scanning over 8 nm "cell groups" to minimize compute cost of primary
//   rays that go all the way to the world border. This may complicate the
//   tracking as large voxels are added incrementally. Defer to a future PR.
// - However, it is okay to use 8 nm voxels to reduce the cost of scanning
//   32 B per static 2 nm voxel atomic counters, while constructing the
//   acceleration structure every frame.
// - Critical distance heuristic is mandatory; warped data distribution where
//   atoms far from the user suffer two-fold: more cost for the primary ray,
//   more divergence for the secondary rays.
//
// Current task:
// - Tackle the CPU-side bottleneck of entering many atoms into Atoms.
//   Profile how long it takes (in ns/atom) to register transactions on macOS
//   and Windows. Embed these profiling results into the source code.
//   - Attempt a subrange version for entering atoms. If it proves a measurable
//     reduction in ns/atom, include it.
//   - Test how the address space size affects the cost of registering a
//     transaction. Record this as a separate metric on macOS and Windows. The
//     cost depends on block size.
// - Get better organized pseudocode of the entire BVH building process for
//   the "end state". This omits the bullet points about rendering in the
//   render kernel. We can probably debug the entire end-state BVH construction
//   process without a single instance of image rendering. Probably a smart
//   move, given the terrible failure modes of a corrupted BVH.

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1080)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  applicationDesc.upscaleFactor = 3
  
  applicationDesc.addressSpaceSize = 20_000_000
  applicationDesc.voxelAllocationSize = 200_000_000
  applicationDesc.worldDimension = 32
  let application = Application(descriptor: applicationDesc)
  
  return application
}
let application = createApplication()

// MARK: - Test Overhead of Atoms API

let atomBlockSize: Int = 5000
for i in 0..<5 {
  // Add the new atoms for this frame.
  do {
    //let start = Date()
    
    // 0 to test (add, move, move, move...)
    // 1 to test (add, add, add, ... eventually reaching the limit)
    let blockStart = 0 * atomBlockSize
    let blockEnd = blockStart + atomBlockSize
    for atomID in blockStart..<blockEnd {
      application.atoms[atomID] = SIMD4(0.0, 0.0, 0.0, 1)
    }
    
    //let end = Date()
    //let latency = end.timeIntervalSince(start)
    //let latencyPerAtom = Double(latency) / Double(atomBlockSize)
    //print(latencyPerAtom)
  }
  
//  do {
//    let start = Date()
    let transaction = application.atoms.registerChanges()
//    let end = Date()
//    let latency = end.timeIntervalSince(start)
//    
//    let addressSpaceSize = application.atoms.addressSpaceSize
//    let latencyPerAtom = Double(latency) / Double(addressSpaceSize)
//    print(latencyPerAtom)
//  }
  
  print()
  print("i = \(i)")
  if transaction.removedIDs.count > 0 {
    let first = transaction.removedIDs.first!
    let last = transaction.removedIDs.last!
    print("removedIDs: \(first)...\(last)")
  }
  if transaction.movedIDs.count > 0 {
    let first = transaction.movedIDs.first!
    let last = transaction.movedIDs.last!
    print("movedIDs: \(first)...\(last)")
    print("movedPositions: \(transaction.movedPositions.count) total")
  }
  if transaction.addedIDs.count > 0 {
    let first = transaction.addedIDs.first!
    let last = transaction.addedIDs.last!
    print("addedIDs: \(first)...\(last)")
    print("addedPositions: \(transaction.addedPositions.count) total")
  }
}
