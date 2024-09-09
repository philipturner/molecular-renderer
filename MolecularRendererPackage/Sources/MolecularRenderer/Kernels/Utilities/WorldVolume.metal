//
//  WorldVolume.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 9/7/24.
//

#ifndef WORLD_VOLUME_H
#define WORLD_VOLUME_H

#include <metal_stdlib>
using namespace metal;

// World volume in nanometers.
//
// The world volume is a 256 nm cube, centered at the origin. Atom coordinates
// may span from -128 to +128.
constexpr constant ushort worldVolumeInNm = 256;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"
constexpr constant ushort cellGroupGridWidth = worldVolumeInNm / 8;
constexpr constant ushort largeVoxelGridWidth = worldVolumeInNm / 2;
constexpr constant ushort smallVoxelGridWidth = worldVolumeInNm * 4;
#pragma clang diagnostic pop

#endif // WORLD_VOLUME_H
