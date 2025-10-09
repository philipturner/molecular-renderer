# BVH Update Process

This is an effort to organize the numerous sub-tasks of the acceleration structure PR, and provide a high-level understanding for those seeking to debug/modify the finished code.

## Acceleration Structure Layout

Simplest implementation:

![Acceleration Structure Layout](./AccelerationStructureLayout.png)

16-bit data types optimization:

![Acceleration Structure Layout (16-Bit)](./AccelerationStructureLayout_16Bit.png)

## Idle/Active Paradigm

Certain allocations ought to be sanitized or reset back to 0, prior to the next frame. When these allocations are very large, scanning the entire buffer would incur an unreasonable bandwidth cost. Instead, one must keep track of which subregions of the buffer were modified. Then, revert the changes as soon as possible.

Affected allocations:
- motion vectors
- 8x duplicated atomic counters for every 2 nm voxel
