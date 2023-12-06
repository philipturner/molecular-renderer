//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import AppKit
import KeyCodes
import Metal
import MolecularRenderer
import OpenMM
import simd

import HDL
import MM4

class Renderer {
  unowned let coordinator: Coordinator
  unowned let eventTracker: EventTracker
  
  // Rendering resources.
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  var renderingEngine: MRRenderer!
  
  // Geometry providers.
  var atomProvider: MRAtomProvider!
  var styleProvider: MRAtomStyleProvider!
  var animationFrameID: Int = 0
  var gifSerializer: GIFSerializer!
  var serializer: Serializer!
  
  // Camera scripting settings.
  static let recycleSimulation: Bool = false
  static let productionRender: Bool = false
  static let programCamera: Bool = false
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    do {
      let descriptor = MRRendererDescriptor()
      descriptor.url = Bundle.main.url(
        forResource: "MolecularRendererGPU", withExtension: "metallib")!
      if Self.productionRender {
        descriptor.width = 720
        descriptor.height = 640
        descriptor.offline = true
      } else {
        descriptor.width = Int(ContentView.size)
        descriptor.height = Int(ContentView.size)
        descriptor.upscaleFactor = ContentView.upscaleFactor
      }
      
      self.renderingEngine = MRRenderer(descriptor: descriptor)
      self.gifSerializer = GIFSerializer(
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.serializer = Serializer(
        renderer: self,
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.styleProvider = NanoStuff()
      initOpenMM()
    }
    
    let lattice = adamantaneLattice()
    
    let latticeAtoms = lattice.entities.map(MRAtom.init)
    var diamondoid = Diamondoid(atoms: latticeAtoms)
    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
    
    // Remove a sidewall carbon, creating two 5-membered rings.
    do {
      #if true
      // Detect the sidewall carbon farthest in Z.
      var maxZValue: Float = -.greatestFiniteMagnitude
      var maxZIndex: Int = -1
      for (index, atom) in diamondoid.atoms.enumerated() {
        if atom.element == 1 {
          continue
        }
        if atom.origin.z > maxZValue {
          maxZValue = atom.origin.z
          maxZIndex = index
        }
      }
      var removedAtoms = [maxZIndex]
      
      // Detect all hydrogens farther in Z than the removed sidewall.
      for (index, atom) in diamondoid.atoms.enumerated() {
        if atom.element != 1 {
          continue
        }
        if atom.origin.z > maxZValue {
          removedAtoms.append(index)
        }
      }
      
      // Create a new bond between the atoms that are about to become free
      // radicals.
      var neighbors: [Int] = []
      for var bond in diamondoid.bonds {
        guard Int(bond[0]) == maxZIndex ||
                Int(bond[1]) == maxZIndex else {
          continue
        }
        if Int(bond[0]) == maxZIndex {
          bond = SIMD2(bond[1], bond[0])
        }
        
        let atom = diamondoid.atoms[Int(bond[0])]
        if atom.element == 1 {
          continue
        }
        neighbors.append(Int(bond[0]))
      }
      guard neighbors.count == 2 else {
        fatalError("Unrecognized number of neighbors.")
      }
      diamondoid.bonds.append(SIMD2(
        Int32(neighbors[0]),
        Int32(neighbors[1])))
      
      // Remove all bonds containing the removed sidewall.
      diamondoid.bonds.removeAll(where: {
        Int($0[0]) == maxZIndex ||
        Int($0[1]) == maxZIndex
      })
      
      // Remove the atoms one at a time, fixing the bonds with a simple
      // O(n^2) method.
      removedAtoms.sort()
      for atomID in removedAtoms.reversed() {
        for bondID in diamondoid.bonds.indices {
          var bond = diamondoid.bonds[bondID]
          if any(bond .== Int32(atomID)) {
            fatalError("A bond remained that contained a removed atom.")
          }
          let shifted = bond &- 1
          bond.replace(with: shifted, where: bond .>= Int32(atomID))
          diamondoid.bonds[bondID] = bond
        }
        diamondoid.atoms.remove(at: atomID)
      }
      #endif
    }
    self.atomProvider = ArrayAtomProvider(diamondoid.atoms)
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = diamondoid.atoms.map { $0.element }
    paramsDesc.bonds = diamondoid.bonds.map {
      SIMD2<UInt32>(truncatingIfNeeded: $0)
    }
    
    // TODO: Re-run with elemental silicon.
    let params = try! MM4Parameters(descriptor: paramsDesc)
    print("atomic numbers (Z):", params.atoms.atomicNumbers)
    print("atomic parameters (r, eps, Hred):", params.atoms.parameters.map {
      ($0.radius.default, $0.epsilon.default, $0.hydrogenReductionFactor)
    })
    print("atom ringTypes:", params.atoms.ringTypes)
    print("rings:", params.rings.indices)
    print()
    print("bond ringTypes:", params.bonds.ringTypes)
    print("bond base parameters (ks, l):", params.bonds.parameters.map { ($0.stretchingStiffness, $0.equilibriumLength) })
    print("bond extended parameters (complex cross-terms):", params.bonds.extendedParameters)
    print()
    print("angle ringTypes:", params.angles.ringTypes)
    print("angle base parameters (kθ, θ, kθθ):",params.angles.parameters.map { ($0.bendingStiffness, $0.equilibriumAngle, $0.bendBendStiffness) })
    print("angle extended parameters (complex cross-terms):", params.angles.extendedParameters)
    print()
    print("torsion ringTypes:", params.torsions.ringTypes)
    print("torsion base parameters (V1, V2, V3, Kts):", params.torsions.parameters.map {
      ($0.V1, $0.Vn, $0.V3, $0.Kts3)
    })
    print("torsion extended parameters (complex cross-terms):", params.torsions.extendedParameters)
  }
}
