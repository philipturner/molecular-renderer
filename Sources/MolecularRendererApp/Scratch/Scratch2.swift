//
//  Scratch2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/28/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// MARK: - Scene

// Accepts the topology for just one crystolecule, instantiates the rest.
func createAnimation(_ topology: Topology) -> AnimationAtomProvider {
  var minimizer = TopologyMinimizer(createScene(topology))
  minimizer.minimize()
  var provider = AnimationAtomProvider([])
  provider.frames.append(minimizer.topology.atoms.map(MRAtom.init))
  
  let totalTime: Double = 20
  let frameTime = totalTime / 500
  for _ in 0..<Int(totalTime/frameTime) {
    minimizer.simulate(time: frameTime)
    provider.frames.append(minimizer.topology.atoms.map(MRAtom.init))
  }
  return provider
}

func createScene(_ topology: Topology) -> Topology {
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  
  var rigidBodyDesc = MM4RigidBodyDescriptor()
  rigidBodyDesc.positions = topology.atoms.map(\.position)
  rigidBodyDesc.parameters = try! MM4Parameters(descriptor: paramsDesc)
  let mainRigidBody = MM4RigidBody(descriptor: rigidBodyDesc)
  
  var sceneTopology = Topology()
  func addRigidBody(_ rigidBody: MM4RigidBody) {
    var insertedAtoms: [Entity] = []
    for i in rigidBody.parameters.atoms.indices {
      let position = rigidBody.positions[i]
      let element = Element(rawValue: rigidBody.atomicNumbers[i])!
      let entity = Entity(position: position, type: .atom(element))
      insertedAtoms.append(entity)
    }
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for bond in rigidBody.parameters.bonds.indices {
      let mappedBond = bond &+ UInt32(sceneTopology.atoms.count)
      insertedBonds.append(mappedBond)
    }
    
    sceneTopology.insert(atoms: insertedAtoms)
    sceneTopology.insert(bonds: insertedBonds)
  }
  
  let rigidBodyCount = 4
  for i in 0..<rigidBodyCount {
    var rigidBody = mainRigidBody
    #if false
    rigidBody.centerOfMass.y += Float(i) * 1.7
    #else
    rigidBody.centerOfMass.x += Float(i) * 0.5
    rigidBody.centerOfMass.z += Float(i) * 0.7
    #endif
    addRigidBody(rigidBody)
  }
  
  return sceneTopology
}

// MARK: - Crystal Geometry

func createLonsdaleiteLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    
    let thickness: Float = 3
    let spacing: Float = 8
    let boundsH: Float = (3+1)*spacing
    Bounds { boundsH * h + 4 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      let cuts = 1 + Int((boundsH/spacing).rounded(.up))
      for i in 0..<cuts {
        Concave {
          Origin { 3.5 * h2k }
          Origin { Float(i) * spacing * h }
          Convex {
            Plane { h + k }
          }
          Convex {
            Plane { h2k }
          }
          Convex {
            Origin { thickness * h }
            Plane { k }
          }
        }
      }
      
      Origin { (-spacing/2) * h }
      for i in 0..<(cuts+1) {
        Concave {
          Origin { 0.5 * h2k }
          Origin { Float(i) * spacing * h }
          Convex {
            Plane { -k }
          }
          Convex {
            Plane { -h2k }
          }
          Convex {
            Origin { thickness * h }
            Plane { -k - h }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}
