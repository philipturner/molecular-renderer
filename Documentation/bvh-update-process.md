# BVH Update Process

This is an effort to organize the numerous sub-tasks of the acceleration structure PR, and provide a high-level understanding for those seeking to debug/modify the finished code.

## Acceleration Structure Layout

Simplest implementation:

![Acceleration Structure Layout](./AccelerationStructureLayout.png)

16-bit data types optimization:

![Acceleration Structure Layout (16-Bit)](./AccelerationStructureLayout_16Bit.png)

Revision: the 16-bit offset is temporary and can be ignored after integrating the atom into the BVH. It will be inaccurate in future frames, as the 2 nm voxel's reference list rearranges to fill empty slots. This realization created an opportunity to reduce the memory footprint per address.

Improvement: 41 bytes/address → 25 bytes/address

## Idle/Active Paradigm

Certain allocations ought to be sanitized or reset back to 0, prior to the next frame. When these allocations are very large, scanning the entire buffer would incur an unreasonable bandwidth cost. Instead, one must keep track of which subregions of the buffer were modified. Then, revert the changes as soon as possible.

Affected allocations:
- motion vectors
- 8x duplicated atomic counters for every 2 nm voxel

Motion vectors are held in the active state by referring to the transaction sent to the GPU during the current frame. After the image is rendered, the motion vectors return to the idle state. Finally, the transaction is forgotten.

Bandwidth-intensive atomic counters are optimized by tagging 8 nm "voxel groups". Only if a voxel group is tagged, will future kernels inspect its 2 nm voxels for modifications. Kernels scoped at the 2 nm level still dispatch one thread per 2 nm voxel in the world volume. However, they use 4x4x4 threadgroups and thus are naturally scoped at 8 nm. The kernels return early when they don't need to perform bandwidth-intensive operations.

## Stages

Remove Process
- tag removed atoms as distinct from others in the address space
- tag impacted 2 nm voxels
- within each 2 nm voxel, search the reference list for atoms to remove
- prefix sum to compact the reference list
- free the memory slots for fully empty voxels

Add Process
- in three GPU kernels, atomically accumulate number of atoms added to each static 2 nm voxel
  - accumulate into one of 8 counters per voxel to reduce memory conflicts, store the atom's assigned offset to RAM
  - sum the 8 counters in each voxel, assign memory slots for completely new voxels
  - write new atom references into end of list in 2 nm voxel
- A small fraction of atoms overlap more than one 2 nm voxel. Although this percentage is low, the chance of 1 thread of a SIMD of 32 having it is much greater. To minimize costs stemming from divergence, the iteration over a 2x2x2 grid of possible overlapping voxels is reordered.

Rebuild Process
- all 2 nm voxels tagged during the previous 2 processes are rebuilt from scratch
  - assumed impossible to recycle any data built at the 0.25 nm level
- all stages fused into a single GPU kernel
  - Register each instance where an atom overlaps a 0.25 nm voxel. Tradeoff between memory efficiency and compute cost determines whether to use cube-sphere intersection test.
  - Perform reductions over the 512 small voxels in the larger voxel, exploiting a conveniently sized threadgroup memory allocation.
  - Generate lists of true number of atoms that intersect a 0.25 nm voxel. Write 16-bit or 32-bit atom references to RAM, incurring the majority of this kernel's bandwidth cost.
  - Read the true size of the per 0.25 nm voxel list from threadgroup memory, store to RAM as bookkeeping data for BVH traversal.

## Memory Allocation

Source: [Atom Reference Duplication (Google Sheets)](https://docs.google.com/spreadsheets/d/1fxRzCieXW_vcBb1BZYGbM1HC4lEH1FEMcF28JEvGtn0/edit?usp=sharing)

Currently using a simple design where every _occupied_ 2 nm voxel gets a fixed chunk of memory to store its data. This wastes a lot of memory. Future implementations could allocate smaller chunks for voxels with low atom density.

| Material | Allocated Atoms | Allocated Refs | Bytes per Voxel |
| -------- | --------------: | -------------: | --------------: |
| C, Au    | 3072            | 20480          | 55304           |
| SiC, Si  | 1536            | 10240          | 28680           |

_Room for improvement if most rendered structures are silicon carbide._

Partial filling of 2 nm voxels will be major problem when working with large static scenes. It will tank the practical atom count below 150M @ 16 GB stated in the Google Sheet. Therefore, another worthwhile optimization is using smaller chunks for partially filled voxels.

| Filling Ratio | Allocated Atoms | Allocated Refs | Bytes per Voxel |
| ------------: | --------------: | -------------: | --------------: |
| 50%           | 768             | 5120           | 15368           |
| 25%           | 384             | 2560           | 8712            |

_Room for improvement if most voxels partially intersect a nanomachine._

Multiple tiers of allocation size will add considerable complexity to the memory management scheme, requiring a careful design that avoids fragmentation. Frequent upgrading/downgrading between allocation tiers would harm performance in dynamic scenes. Therefore, the backend will auto-detect which voxels are moving and leave them at a large size, migrating to a smaller allocation after a small time delay. This migration will not incur the compute cost of rebuilding a voxel.

The delayed migration design also seems like the most sensible way to program the allocator. When allocations are acquired, only the atom count is known. The reference count is not known until the voxel gets rebuilt. It could be that the atom count for a specific tier is met, but the reference count is exceed. It would be overcomplicated to migrate to a new memory slot _during_ the kernel that rebuilds voxels. It would be much easier to migrate during a following frame.

### Algorithm for Current Design

Every frame, garbage collect or scan the entire array of memory slots. Create a compacted list of available ones. Do this right after the "remove process", so the "add process" can read from the list.

If all slots in the list of available ones are used up, the GPU writes to a crash buffer. Every single GPU kernel in the entire Molecular Renderer library must read this crash buffer. If set to an error value, the kernel returns early or produces a sensible default output.
