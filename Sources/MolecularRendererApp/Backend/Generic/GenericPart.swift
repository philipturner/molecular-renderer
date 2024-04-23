//
//  GenericPart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

// A convenience method for de-duplicating the most common pieces of code.
protocol GenericPart {
  var rigidBody: MM4RigidBody { get set }
}

extension GenericPart {
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    reconstruction.topology.sort()
    return reconstruction.topology
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  
  // Extract the atoms that should be fixed during minimization.
  static func extractBulkAtomIDs(topology: Topology) -> [UInt32] {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var bulkAtomIDs: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let atomElement = Element(rawValue: atom.atomicNumber)!
      let atomRadius = atomElement.covalentRadius
      
      let neighborIDs = atomsToAtomsMap[atomID]
      var carbonNeighborCount: Int = .zero
      var correctBondCount: Int = .zero
      
      for neighborID in neighborIDs {
        let neighbor = topology.atoms[Int(neighborID)]
        let neighborElement = Element(rawValue: neighbor.atomicNumber)!
        let neighborRadius = neighborElement.covalentRadius
        if neighbor.atomicNumber == 6 {
          carbonNeighborCount += 1
        }
        
        let delta = atom.position - neighbor.position
        let bondLength = (delta * delta).sum().squareRoot()
        let expectedBondLength = atomRadius + neighborRadius
        if bondLength / expectedBondLength < 1.1 {
          correctBondCount += 1
        }
      }
      
      if carbonNeighborCount == 4, correctBondCount == 4 {
        bulkAtomIDs.append(UInt32(atomID))
      }
    }
    return bulkAtomIDs
  }
  
  // Finds the surface geometry with an accuracy of 0.1 zJ.
  mutating func minimize(bulkAtomIDs: [UInt32]) {
    var forceFieldParameters = rigidBody.parameters
    for atomID in bulkAtomIDs {
      forceFieldParameters.atoms.masses[Int(atomID)] = .zero
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = forceFieldParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = rigidBody.positions
    forceField.minimize(tolerance: 0.1)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = rigidBody.parameters
    rigidBodyDesc.positions = forceField.positions
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

extension GenericPart {
  // Generates a hash from the atoms. Typically, this will come straight from
  // the compiled lattice.
  static func hash(atoms: [Entity]) -> Data {
    var xorHash: SIMD4<UInt32> = .zero
    var rotateHash: SIMD4<UInt32> = .one
    var floatSum: SIMD4<UInt32> = .zero
    
    for atom in atoms {
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
    let data = try? Data(contentsOf: url)
    guard let data else {
      print("[\(Self.self)] Cache miss: file not found.")
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
    guard key == cacheKey else {
      print("[\(Self.self)] Cache miss: key mismatch.")
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
