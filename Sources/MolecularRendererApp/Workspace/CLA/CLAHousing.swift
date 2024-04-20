//
//  CLAHousing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAHousingDescriptor {
  var rods: [Rod] = []
  var cachePath: String?
}

struct CLAHousing: GenericPart {
  var rigidBody: MM4RigidBody
  
  init(descriptor: CLAHousingDescriptor) {
    // Load the structure from disk.
    let lattice = Self.createLattice(rods: descriptor.rods)
    var cachedStructure: Topology?
    if let cachePath = descriptor.cachePath {
      let key = Self.hash(lattice: lattice)
      cachedStructure = Self.load(key: key, cachePath: cachePath)
    }
    
    // Assign the topology and rigid body.
    var topology: Topology
    if let cachedStructure {
      topology = cachedStructure
    } else {
      topology = Self.createTopology(lattice: lattice)
    }
    rigidBody = Self.createRigidBody(topology: topology)
    
    // Save the structure to disk, regardless of whether it was already loaded.
    if let cachePath = descriptor.cachePath {
      let key = Self.hash(lattice: lattice)
      save(key: key, cachePath: cachePath)
    }
    
    rigidBody.centerOfMass.z -= 18 * 0.3567
  }
  
  static func createLattice(rods: [Rod]) -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 74 * h + 38 * k + 59 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Remove a slab of atoms from the front.
        Convex {
          Origin { 58.25 * l }
          Plane { l }
        }
        
        // Remove a slab of atoms from the bottom.
        Convex {
          Origin { 2 * k }
          Plane { -k }
        }
        
        // Remove a chunk in the [-X, -Z] direction.
        Concave {
          Origin { 50 * h }
          Plane { -h }
          
          Origin { 18 * l }
          Plane { -l }
        }
        
        // Remove a chunk in the [+X, +Z] direction.
        Concave {
          Origin { 64.25 * h }
          Plane { h }
          
          Origin { 14 * l }
          Plane { l }
        }
        Replace { .empty }
      }
      
      // Remove chunks that spawned from the carry out.
      Volume {
        // Remove a chunk in the [-X, +Y] direction.
        Concave {
          Origin { 50 * h }
          Plane { -h }
          
          Origin { 34.5 * k }
          Plane { k }
        }
        
        // Remove a chunk in the [+X, +Y] direction.
        Concave {
          Origin { 58 * h }
          Plane { h }
          
          Origin { 34.5 * k }
          Plane { k }
        }
        
        Replace { .empty }
      }
      
      // Remove a layer from the bottom of the entire machine.
      Volume {
        // Remove a chunk in the [+X, -Z] direction.
        Concave {
          Origin { 20 * h }
          Plane { h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 42 * l }
          Plane { -l }
        }
        
        // Remove a chunk in the [-X, -Z] direction.
        Concave {
          Origin { 12 * h }
          Plane { -h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 42 * l }
          Plane { -l }
        }
        
        // Remove a chunk in the [+X, +Z] direction.
        Concave {
          Origin { 40 * h }
          Plane { h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 50 * l }
          Plane { l }
        }
        
        // Remove a chunk in the [-X, +Z] direction.
        Concave {
          Origin { 12 * h }
          Plane { -h }
          
          Origin { 6 * k }
          Plane { -k }
          
          Origin { 50 * l }
          Plane { l }
        }
        
        Replace { .empty }
      }
      
      // Remove a set of chunks, which appear like steps.
      // - Only trimming the first step.
      Volume {
        // Y=6 to Y=12
        Concave {
          Concave {
            Origin { 26 * h }
            Plane { h }
          }
          Concave {
            Origin { 50 * h }
            Plane { -h }
          }
          
          Origin { 12 * k }
          Plane { -k }
          
          Origin { 36 * l }
          Plane { -l }
        }
        
        Replace { .empty }
      }
      
      // Remove chunks for the holes.
      Volume {
        for rod in rods {
          var volume = rod.createExcludedVolume(padding: 0)
          volume.minimum.z += 18
          volume.maximum.z += 18
          
          Concave {
            Concave {
              Origin { volume.minimum * (h + k + l) }
              Plane { h }
              Plane { k }
              Plane { l }
            }
            Concave {
              Origin { volume.maximum * (h + k + l) }
              Plane { -h }
              Plane { -k }
              Plane { -l }
            }
          }
        }
        Replace { .empty }
      }
    }
  }
}

extension CLAHousing {
  static func hash(lattice: Lattice<Cubic>) -> Data {
    var xorHash: SIMD4<UInt32> = .zero
    var rotateHash: SIMD4<UInt32> = .one
    var floatSum: SIMD4<UInt32> = .zero
    
    for atom in lattice.atoms {
      let storage = atom.storage
      let storageCasted = unsafeBitCast(storage, to: SIMD4<UInt32>.self)
      
      xorHash ^= storageCasted
      xorHash = (xorHash &<< 3) | (xorHash &>> (32 - 3))
      
      rotateHash &*= storageCasted
      rotateHash &+= 1
      rotateHash = (rotateHash &<< 9) | (rotateHash &>> (32 - 9))
      
      var quantized = atom.storage
      quantized *= 1024
      quantized.round(.toNearestOrEven)
      floatSum &+= unsafeBitCast(quantized, to: SIMD4<UInt32>.self)
    }
    
    var data = Data()
    func addVector(_ vector: SIMD4<UInt32>) {
      let castedVector = unsafeBitCast(vector, to: SIMD16<UInt8>.self)
      for laneID in 0..<16 {
        let byte = castedVector[laneID]
        data.append(byte)
      }
    }
    addVector(xorHash)
    addVector(rotateHash)
    addVector(floatSum)
    return data
  }
  
  static func load(key: Data, cachePath: String) -> Topology? {
    // Load the structure from the disk.
    let url = URL(fileURLWithPath: cachePath)
    var data = try? Data(contentsOf: url)
    guard let data else {
      print("[CLAHousing] Cache miss: file not found.")
      return nil
    }
    
    // Decode the header.
    guard data.count >= 32 else {
      fatalError("Data had invalid header.")
    }
    var headerCasted: SIMD32<UInt8> = .zero
    for laneID in 0..<32 {
      let byte = data[laneID]
      headerCasted[laneID] = byte
    }
    let header = unsafeBitCast(headerCasted, to: SIMD4<UInt64>.self)
    
    // Check that the file has the correct size.
    let keySize = header[0]
    let valueAtomsSize = header[1]
    let valueBondsSize = header[2]
    let expectedSize = 32 + keySize + valueAtomsSize + valueBondsSize
    guard expectedSize == data.count else {
      fatalError("File had the wrong size.")
    }
    
    // Divide the file into segments.
    var cursor: UInt64 = 32
    let keyRange = cursor..<cursor + keySize
    cursor += keySize
    let valueAtomsRange = cursor..<cursor + valueAtomsSize
    cursor += valueAtomsSize
    let valueBondsRange = cursor..<cursor + valueBondsSize
    cursor += valueBondsSize
    guard cursor == data.count else {
      fatalError("Cursor was invalid.")
    }
    
    // Extract the segments of the file.
    let cacheKey = Data(data[keyRange])
    guard key.count == cacheKey.count else {
      print("[CLAHousing] Cache miss: key mismatch.")
      return nil
    }
    let valueAtoms = Data(data[valueAtomsRange])
    let valueBonds = Data(data[valueBondsRange])
    let atoms = Serialization.deserialize(atoms: valueAtoms)
    let bonds = Serialization.deserialize(bonds: valueBonds)
    
    // Create a topology.
    var topology = Topology()
    topology.insert(atoms: atoms)
    topology.insert(bonds: bonds)
    return topology
  }
  
  func save(key: Data, cachePath: String) {
    // Extract the atoms and bonds.
    var rigidBodyAtoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
      rigidBodyAtoms.append(entity)
    }
    let rigidBodyBonds = rigidBody.parameters.bonds.indices
    
    // Compress the data.
    let valueAtoms = Serialization.serialize(atoms: rigidBodyAtoms)
    let valueBonds = Serialization.serialize(bonds: rigidBodyBonds)
    
    // Create the header.
    var header: SIMD4<UInt64> = .zero
    header[0] = UInt64(key.count)
    header[1] = UInt64(valueAtoms.count)
    header[2] = UInt64(valueBonds.count)
    let headerCasted = unsafeBitCast(header, to: SIMD32<UInt8>.self)
    
    // Combine the header and data into a single binary.
    var data = Data()
    for laneID in 0..<32 {
      let byte = headerCasted[laneID]
      data.append(byte)
    }
    data.append(key)
    data.append(valueAtoms)
    data.append(valueBonds)
    
    // Save the structure to the disk.
    let url = URL(fileURLWithPath: cachePath)
    try! data.write(to: url)
  }
}
