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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"
// World volume in nanometers.
constexpr constant ushort worldVolumeInNm = 128;
constexpr constant ushort largeVoxelGridWidth = worldVolumeInNm / 2;
constexpr constant ushort smallVoxelGridWidth = worldVolumeInNm * 4;
#pragma clang diagnostic pop

#endif // WORLD_VOLUME_H
