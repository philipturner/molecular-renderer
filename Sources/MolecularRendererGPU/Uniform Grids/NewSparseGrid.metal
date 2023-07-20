//
//  NewSparseGrid.metal
//  MolecularRendererGPU
//
//  Created by Philip Turner on 7/17/23.
//

#include <metal_stdlib>
#include "../Utilities/Atomic.metal"
#include "../Utilities/FaultCounter.metal"
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
    
    template <typename T>
    class allocation;
    
    class lower_voxel;
    
    class upper_voxel;
    
    class grid;
    
    class chunk;
    
    class heap;
  };
};

template <typename T>
class metal::raytracing::allocation {
  uint _offset;
  
public:
  allocation(uint offset): _offset(offset) {}
  
  // If the offset is zero, the pointer is null.
  device T* get_pointer(device void *heap) {
    return (device T*)((device uchar*)heap + _offset * 256 * 1024);
  }
};

class metal::raytracing::lower_voxel {
public:
  ushort data[32];
  
  ushort get_count() const {
    return data[31];
  }
  
  void set_count(ushort count) {
    data[31] = count;
  }
};

class metal::raytracing::upper_voxel {
public:
  static constant uint atoms_bits = 14;
  static constant uint id_bits = 32 - atoms_bits;
  static constant uint id_mask = (1 << id_bits) - 1;
  static constant uint max_atoms = 1 << atoms_bits;
  
  // 256 KB
  // - 16384 x 16 B
  class atoms {
  public:
    MRAtom atoms[max_atoms];
  };
  
  // 256 KB
  // - 4096 x 64 B
  class references {
  public:
    lower_voxel voxels[16 * 16 * 16];
  };
  
  // 256 KB
  // - 16384 x 4 B
  // - 192 KB for other data
  class other {
  public:
    uint atom_ids[max_atoms];
    uint num_atoms;
  };
  
  allocation<atoms> atoms;
  allocation<references> references;
  allocation<other> other;
};

class metal::raytracing::grid {
public:
  // 64 MB
  // - 2^24 * 4 B
  allocation<upper_voxel> voxels[256 * 256 * 256];
};

class metal::raytracing::chunk {
public:
  static constant uint byte_alignment = 512 * 4;
  static constant uint num_pages = 256;
  
  uint pages[num_pages];
  ushort free_indices[num_pages];
  uint local_free_index;
  uint global_free_index;
  uint num_free_indices;
  
  ushort get_free_index() device {
    uint slot = atomic_fetch_add(&local_free_index, 1);
    return free_indices[slot];
  }
};

class metal::raytracing::heap {
public:
  device uint *metadata;
  device void *pages;
  device void *chunks;
  
  uint get_num_chunks() const {
    return metadata[0];
  }
  
  uint get_free_capacity() const {
    return metadata[1];
  }
  
  uint get_free_used() const {
    return atomic_load(metadata + 2);
  }
  
  uint increment_free_used() {
    return atomic_fetch_add(metadata + 2, 1);
  }
  
  device chunk* get_chunk(uint chunk_id) {
    auto chunks_bytes = (device uchar*)chunks;
    chunks_bytes += chunk_id * chunk::byte_alignment;
    return (device chunk*)chunks_bytes;
  }
  
  uint malloc() {
    uint free_page_id = increment_free_used();
    if (free_page_id >= get_free_capacity()) {
      return 0;
    }
    uint actual_page_id = 0;
    
    // Basic algorithm from:
    // https://en.wikipedia.org/wiki/Binary_search_algorithm
    uint left = 0;
    uint right = get_num_chunks() - 1;
    FaultCounter counter(1000);
    while (left <= right) {
      if (counter.quit()) {
        return 0;
      }
      
      uint middle = (left + right) / 2;
      auto chunk = get_chunk(middle);
      uint base_index = chunk->global_free_index;
      uint ceil_index = base_index + chunk->num_free_indices;
      
      if (base_index <= free_page_id && free_page_id < ceil_index) {
        actual_page_id = chunk->get_free_index();
        break;
      } else if (base_index <= free_page_id) {
        left = middle + 1;
      } else {
        right = middle - 1;
      }
    }
    return actual_page_id;
  }
};

#pragma clang diagnostic pop
