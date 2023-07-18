//
//  NewSparseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/17/23.
//

#include <metal_stdlib>
#include "../Utilities/MRAtom.metal"
using namespace metal;
using namespace raytracing;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

// The highest atom density is 176 atoms/nm^3 with diamond. A superdense carbon
// allotrope is theorized with 354 atoms/nm^3 (1), but the greatest superdense
// ones actually built are ~1-3% denser (2). 256 atoms/nm^3 is a close upper
// limit. It provides just enough room for overlapping atoms from nearby voxels
// (216-250 atoms/nm^3).
//
// 4x4x4 nm^3 voxels, 16384 atoms/voxel, <256 atoms/nm^3
//
// (1) https://pubs.aip.org/aip/jcp/article-abstract/130/19/194512/296270/Structural-transformations-in-carbon-under-extreme?redirectedFrom=fulltext
// (2) https://www.newscientist.com/article/dn20551-new-super-dense-forms-of-carbon-outshine-diamond/

namespace metal {
  namespace raytracing {
    class context;
    
    class heap;
    
    template <typename T>
    class allocation;
    
    template <typename T>
    class range;
    
    class grid;
    
    class upper_voxel;
    
    class reference_page;
  };
};

class metal::raytracing::heap {
public:
  device grid *previous_grid;
  device grid *current_grid;
  
  // 256 KB pages, each containing an occupancy flag
  device void *heap;
  uint heap_capacity;
};

template <typename T>
class metal::raytracing::allocation {
  uint _offset;
  
public:
  allocation(uint offset): _offset(offset) {}
  
  device T* get_pointer(device void *heap) {
    return (device T*)((device uchar*)heap + _offset * 256 * 1024);
  }
};

template <typename T>
class metal::raytracing::range {
  uint _mask;
  
public:
  range(uint mask): _mask(mask) {}
  
  uint get_offset(constant uint &address_bits) {
    return _mask & ((1 << address_bits) - 1);
  }
  
  ushort get_count(constant uint &address_bits) {
    return _mask >> address_bits;
  }
};

class metal::raytracing::grid {
public:
  short3 origin;
  ushort3 bounds;
  allocation<upper_voxel> upper_voxels;
};

class metal::raytracing::upper_voxel {
public:
  static constant uint atoms_bits = 14;
  static constant uint id_bits = 32 - atoms_bits;
  static constant uint id_mask = (1 << id_bits) - 1;
  static constant uint max_atoms = 1 << atoms_bits;
  
  // 256 KB
  // - 16383 x 16 B
  // - 16 B for flag
  class atoms {
  public:
    MRAtom atoms[max_atoms];
  };
  
  // 256 KB
  // - 16384 x 8 B
  // - 27000 x 4 B
  // - 23072 B for other data
  class data {
  public:
    ushort4 hashes[max_atoms];
    range<ushort> lower_voxels[30 * 30 * 30];
    allocation<reference_page> reference_pages[8];
  };
  
  allocation<atoms> atoms;
  allocation<data> data;
};

// 256 KB
// - 32 x 7.98 KB
// - 16 B for flag
//
// Final resolution tiers:
// 4/ 8-10 nm -> 2x2x2/nm^3
// 4/12-14 nm -> 3x3x3/nm^3
// 4/16-18 nm -> 4x4x4/nm^3
// 4/20-22 nm -> 5x5x5/nm^3
// 4/24-30 nm -> 6x6x6/nm^3
//
// 2x2x4 - 8.0 KB, ~256 refs/lower voxel
// 3x3x4 - 7.9 KB, ~113 refs/lower voxel
// 4x4x4 - 8.0 KB, ~64 refs/lower voxel
// 5x5x4 - 7.5 KB, ~40 refs/lower voxel
// 6x6x4 - 7.8 KB, ~28 refs/lower voxel
class metal::raytracing::reference_page {
public:
};

#pragma clang diagnostic pop
