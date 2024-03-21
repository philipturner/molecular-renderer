// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test whether you can have a knob on the (111) side of the lonsdaleite, to
// facilitate 3D data transfers. There are suspected to cause the rod to warp,
// so we need a method to compensate.
func createGeometry() -> [[Entity]] {
  var rodDesc = RodDescriptor()
  rodDesc.dopantElement = .carbon
  var rodC = Rod(descriptor: rodDesc)
  for atomID in rodC.topology.atoms.indices {
    var atom = rodC.topology.atoms[atomID]
    atom.position += SIMD3(0, 0, -3)
    rodC.topology.atoms[atomID] = atom
  }
  
  rodDesc.dopantElement = .silicon
  var rodSi = Rod(descriptor: rodDesc)
  for atomID in rodSi.topology.atoms.indices {
    var atom = rodSi.topology.atoms[atomID]
    atom.position += SIMD3(0, 0, 0)
    rodSi.topology.atoms[atomID] = atom
  }
  
  rodDesc.dopantElement = .germanium
  var rodGe = Rod(descriptor: rodDesc)
  for atomID in rodGe.topology.atoms.indices {
    var atom = rodGe.topology.atoms[atomID]
    atom.position += SIMD3(0, 0, 3)
    rodGe.topology.atoms[atomID] = atom
  }
  
  var topologies: [Topology] = []
  topologies.append(rodC.topology)
  topologies.append(rodSi.topology)
  topologies.append(rodGe.topology)
  
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  
  for topology in topologies {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let rodParameters = try! MM4Parameters(descriptor: paramsDesc)
    systemParameters.append(contentsOf: rodParameters)
  }
  

  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = systemParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  var combinedPositions: [SIMD3<Float>] = []
  combinedPositions += topologies[0].atoms.map(\.position)
  combinedPositions += topologies[1].atoms.map(\.position)
  combinedPositions += topologies[2].atoms.map(\.position)
  forceField.positions = combinedPositions
  forceField.minimize()
  
  var frames: [[Entity]] = []
  for frameID in 0...600 {
    if frameID > 0 {
      forceField.simulate(time: 0.040)
    }
    
    var frame: [Entity] = []
    for atomID in systemParameters.atoms.indices {
      let atomicNumber = systemParameters.atoms.atomicNumbers[atomID]
      let position = forceField.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let entity = Entity(storage: storage)
      frame.append(entity)
    }
    frames.append(frame)
  }
  return frames
}

struct RodDescriptor {
  var dopantElement: Element?
}

struct Rod {
  var topology = Topology()
  
  init(descriptor: RodDescriptor) {
    createLattice(descriptor: descriptor)
    passivate()
  }
  
  mutating func createLattice(descriptor: RodDescriptor) {
    guard let dopantElement = descriptor.dopantElement else {
      fatalError("Descriptor was not complete.")
    }
    
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 40 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      func knob1(startH: Float) {
        Concave {
          Origin { startH * h }
          Plane { h }
          
          Origin { 1.49 * l }
          Plane { l }
          
          Origin { 6 * h }
          Plane { -h }
        }
      }
      
      func knob2(startH: Float) {
        Concave {
          Origin { startH * h }
          Plane { h }
          
          Origin { 1.49 * l }
          Plane { l }
          
          Origin { 6 * h }
          Plane { -h }
        }
      }
      
      func siliconDopants1(startH: Float) {
        Concave {
          Origin { startH * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 1 * l }
          Plane { l }
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 1 * h2k }
          Plane { -h2k }
        }
        Concave {
          Origin { (startH + 5) * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 1 * l }
          Plane { l }
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 1 * h2k }
          Plane { -h2k }
        }
      }
      
      func siliconDopants2(startH: Float) {
        Concave {
          Origin { startH * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 1 * l }
          Plane { l }
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 1 * h2k }
          Plane { h2k }
        }
        Concave {
          Origin { (startH + 5) * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 1 * l }
          Plane { l }
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 1 * h2k }
          Plane { h2k }
        }
      }
      
      Volume {
        knob1(startH: 3)
        knob2(startH: 11.5)
        knob1(startH: 24)
        knob2(startH: 31.5)
        Replace { .empty }
      }
      
      Volume {
        siliconDopants1(startH: 3)
        siliconDopants2(startH: 11.5)
        siliconDopants1(startH: 24)
        siliconDopants2(startH: 31.5)
        Replace { .atom(dopantElement) }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Adds C-H bonds, then sorts the atoms for efficient simulation.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}
