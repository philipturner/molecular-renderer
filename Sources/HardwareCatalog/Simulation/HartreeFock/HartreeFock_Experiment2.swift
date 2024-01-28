//
//  HartreeFock_Experiment2.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 1/27/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct OrbitalFragment {
  // in Bohr, with 0.2 Å spacing
  var position: SIMD3<Float>
  
  // square root of occupancy
  // density = occupancy / microvolume
  // sometimes is actually the wavefunction scaled by energy
  var wavefunction: Float
}

let gridWidth: Int = 50
let spacing: Float = 0.010

func createGeometry() -> [[Entity]] {
  // TODO: Rewrite the code from scratch, again. This time, ensure the kinetic
  // energy of hydrogen ground-state orbitals is computed correctly. Compute
  // it analytically by hand, then figure out why the program reports
  // something else.
  // - Don't include the Hartree or exchange terms in the next code rewrite.
  //   Just the kinetic and external energy.
  // - This is still a single-electron system. We need to prove that the
  //   Schrodinger equation produces an orbital strongly reminiscent of the
  //   hydrogen 1s orbital.
  
  
  
  // A common reason for divergence was entering a forbidden region. The
  // kinetic energy explodes because its sign is the same as the
  // wavefunction. For example, collapsing into the nucleus. These are failure
  // modes of the computer algorithm. They are likely a symptom of something
  // else that is being done incorrectly.
  
  
  
  // Solve the Hartree equation with finite-differencing, visualizing the
  // evolution of the 2s orbital into the 1s orbital. Then, experiment with
  // multigrids.
  //
  // Defer investigation of more complex things (variable-resolution orbitals,
  // multi-electron orthogonalization, exchange-correlation) to a future
  // design iteration. The code may be rewritten from scratch before that
  // stuff is investigated.
  //
  // Work breakdown structure:
  // - Start with the classical nuclear repulsion term.
  // - Add the Hartree term. This doesn't require finite-differencing.
  //   - According to the Hartree equation, the electron shouldn't be repelled
  //     by itself. Does the self-interaction make this simulation unstable?
  //   - Observe how the solver behaves, e.g. something reminiscent of 2s
  //     evolving into 1s. Is there "critical slowing down" with finer
  //     resolution?
  // - Add 2nd-order finite-differencing for the Hartree term.
  //   - Why do people stress the need for "multipole expansion" at the
  //     boundaries of the uniform grid?
  // - Add 2nd-order finite-differencing for the kinetic term.
  // - Investigate multigrids for the Poisson solver, with an interpolation
  //   scheme suitable for variable-resolution orbitals.
  // - Investigate multigrids for the eigensolver.
  
  // Create a 30x30x30 grid of orbital fragments.
  var fragments: [OrbitalFragment] = []
  for zIndex in -gridWidth/2..<gridWidth/2 {
    for yIndex in -gridWidth/2..<gridWidth/2 {
      for xIndex in -gridWidth/2..<gridWidth/2 {
        var position = SIMD3<Float>(
          Float(xIndex),
          Float(yIndex),
          Float(zIndex))
        position += 0.5
        position *= spacing
        position /= 0.0529177
        
        // 1s orbital of hydrogen.
        let Z: Float = 1
        let r: Float = (position * position).sum().squareRoot()
        let n: Float = 2
        let a: Float = 1
        var wavefunction = exp(-Z * r / (n * a)) * (2 * Z * r / (n * a))
        
        let l: Float = 0
        let alpha = 2 * l + 1
        let L_1 = 1 + alpha - r
        wavefunction *= L_1
        
        let fragment = OrbitalFragment(
          position: position, wavefunction: wavefunction)
        fragments.append(fragment)
      }
    }
  }
  fragments = normalize(fragments: fragments)
  var previousDensity = createDensity(fragments: fragments)
  print()
  var cursor = 0
  for zIndex in -gridWidth/2..<gridWidth/2 {
    for yIndex in -gridWidth/2..<gridWidth/2 {
      for xIndex in -gridWidth/2..<gridWidth/2 {
        if zIndex == 6 && yIndex == 6 {
//          print("\(fragments[cursor].position.x), \(fragments[cursor].wavefunction),")
        }
        cursor += 1
      }
    }
  }
  
  var output: [[Entity]] = []
  for frameID in 0..<50 {
    if frameID > 0 {
      let nextPreviousDensity = createDensity(fragments: fragments)
      let previous = fragments
      let energyψ = hamiltonian(
        fragments: fragments,
        previousDensity: nextPreviousDensity) // deactivate density mixing
      
      var ψ = normalize(fragments: energyψ)
      for i in fragments.indices {
        ψ[i].wavefunction = -ψ[i].wavefunction
        if frameID < 20 {
          fragments[i].wavefunction =
          0.10 * ψ[i].wavefunction +
          0.90 * previous[i].wavefunction
        } else {
          fragments[i].wavefunction =
          ψ[i].wavefunction
        }
      }
      fragments = normalize(fragments: fragments)
      previousDensity = nextPreviousDensity
    }
    
    let rendered = renderElectron(fragments)
    for _ in 0..<1 {
      output.append(rendered)
    }
  }
  
  /*
   1s orbital + 15 steps
   
   ============ Energy (Hartree) ==============
   |   Hamiltonian         : 2.0319252247838904
   |   Sum Energy          : 2.0319255824123807
   |   "Energy"            : 2.031941570363415
   --------------------------------------------
   | * Ion-ion Energy      : 0.0
   | * Eigenvals sum for 0 : 0
   | * Hartree Energy      : 2.6719095458813626
   | * XC Energy           : -1.3027477371813951
   | * Kinetic Energy      : 3.717959856629932
   | * External Energy     : -3.0551960829175187
   | * Non-local Energy    : 0
   ============================================
   
   1s orbital + 100 steps
   
   ============ Energy (Hartree) ==============
   |   Hamiltonian         : 2.0266494750976562
   |   Sum Energy          : 2.026649594306946
   |   "Energy"            : 2.0266494750976562
   --------------------------------------------
   | * Ion-ion Energy      : 0.0
   | * Eigenvals sum for 0 : 0
   | * Hartree Energy      : 2.6719298362731934
   | * XC Energy           : -1.3027609586715698
   | * Kinetic Energy      : 3.7126858234405518
   | * External Energy     : -3.0552051067352295
   | * Non-local Energy    : 0
   ============================================
   
   2s orbital + 15 steps
   
   ============ Energy (Hartree) ==============
   |   Hamiltonian         : 2.0382421394697303
   |   Sum Energy          : 2.03824213946956
   |   "Energy"            : 2.038324843706505
   --------------------------------------------
   | * Ion-ion Energy      : 0.0
   | * Eigenvals sum for 0 : 0
   | * Hartree Energy      : 2.6718290389071626
   | * XC Energy           : -1.302695640826812
   | * Kinetic Energy      : 3.7242691404771904
   | * External Energy     : -3.055160399087981
   | * Non-local Energy    : 0
   ============================================
   
   (wavefunction = Y coordinate) + 15 steps
   
   ============ Energy (Hartree) ==============
   |   Hamiltonian         : 5.669740826025641
   |   Sum Energy          : 5.669740587607061
   |   "Energy"            : 5.669741317890219
   --------------------------------------------
   | * Ion-ion Energy      : 0.0
   | * Eigenvals sum for 0 : 0
   | * Hartree Energy      : 3.3650262254463192
   | * XC Energy           : -1.6413760198664156
   | * Kinetic Energy      : 7.0012958412153585
   | * External Energy     : -3.055205459188201
   | * Non-local Energy    : 0
   ============================================
   */
  
  return output
}

// MARK: - Utilities

// Extract the energy of the wavefunction.
func createEnergy(fragments: [OrbitalFragment]) -> Double {
  let ψ = normalize(fragments: fragments)
  let Eψ = fragments
  
  var ψEψ: Double = .zero
  for i in fragments.indices {
    ψEψ += Double(ψ[i].wavefunction * Eψ[i].wavefunction)
  }
  return ψEψ
}

// Create densities from the wavefunction.
func createDensity(fragments: [OrbitalFragment]) -> [SIMD4<Float>] {
  var density: [SIMD4<Float>] = []
  for i in fragments.indices {
    let cellWidth: Float = spacing / 0.0529177
    let microvolume = cellWidth * cellWidth * cellWidth
    let fragment = fragments[i]
    
    let occupancy = fragment.wavefunction * fragment.wavefunction
    density.append(SIMD4(fragment.position, occupancy / microvolume))
  }
  return density
}

// Normalize the wavefunction.
func normalize(fragments: [OrbitalFragment]) -> [OrbitalFragment] {
  var norm: Double = .zero
  for fragment in fragments {
    norm += Double(fragment.wavefunction * fragment.wavefunction)
  }
  norm.formSquareRoot()
  
  let normalizationFactor = Float(1 / norm)
  var newFragments = fragments
  for i in newFragments.indices {
    newFragments[i].wavefunction *= normalizationFactor
  }
  return newFragments
}

func dot(_ lhs: [OrbitalFragment], _ rhs: [OrbitalFragment]) -> Double {
  let ψ = lhs
  let Eψ = rhs
  
  var ψEψ: Double = .zero
  for i in lhs.indices {
    ψEψ += Double(ψ[i].wavefunction * Eψ[i].wavefunction)
  }
  return ψEψ
}

// Multiply the wavefunction by the hamiltonian.
func hamiltonian(
  fragments: [OrbitalFragment],
  previousDensity: [SIMD4<Float>]
) -> [OrbitalFragment] {
  let newDensity = createDensity(fragments: fragments)
  var densities: [SIMD4<Float>] = []
  for i in previousDensity.indices {
    densities.append(previousDensity[i] * 0.7 + newDensity[i] * 0.3)
  }
  
  var hartreeψ = fragments
  var exchangeψ = fragments
  var kineticψ = fragments
  var externalψ = fragments
  var energyψ = fragments
  
  for zIndex in -gridWidth/2..<gridWidth/2 {
    for yIndex in -gridWidth/2..<gridWidth/2 {
      for xIndex in -gridWidth/2..<gridWidth/2 {
        let coords = gridWidth/2 &+ SIMD3(xIndex, yIndex, zIndex)
        let addressDeltas = SIMD3<Int>(1, gridWidth, gridWidth * gridWidth)
        
        // Create the kinetic energy term.
        var kineticEnergy: Float = 0
        for laneID in 0..<3 {
          var coordsDelta = SIMD3<Int>.zero
          coordsDelta[laneID] = 1
          var coordsArray: [SIMD3<Int>] = []
          coordsArray.append(coords &- coordsDelta &* 2)
          coordsArray.append(coords &- coordsDelta &* 1)
          coordsArray.append(coords)
          coordsArray.append(coords &+ coordsDelta &* 1)
          coordsArray.append(coords &+ coordsDelta &* 2)
          
          var samples: [Float] = []
          var coordSamples: [SIMD3<Float>] = []
          for coordsElement in coordsArray {
            guard all(coordsElement .>= 0), all(coordsElement .< gridWidth) else {
              samples.append(0)
              coordSamples.append(.zero)
              continue
            }
            let address = (coordsElement &* addressDeltas).wrappedSum()
            samples.append(fragments[address].wavefunction)
            coordSamples.append(fragments[address].position)
          }
          
          // jhwoo15/GOSPEL, Fighting!!
          let cellWidth: Float = spacing / 0.0529177
          let denominator = cellWidth * cellWidth
          let contribution =
          samples[0] * Float(-1) / 12 +
          samples[1] * Float(4) / 3 +
          samples[2] * Float(-5) / 2 +
          samples[3] * Float(4) / 3 +
          samples[4] * Float(-1) / 12
//          samples[1] * 1 +
//          samples[2] * -2 +
//          samples[3] * 1
          
          /*
           0 [SIMD3<Float>(0.0, 0.0, 0.0),
           SIMD3<Float>(0.0, 0.0, 0.0),
           SIMD3<Float>(-19.464186, -19.464186, -19.464186),
           SIMD3<Float>(-19.08624, -19.464186, -19.464186),
           SIMD3<Float>(-18.708296, -19.464186, -19.464186)]
           */
          
          // spacing: 0.010 Å
          // 2nd order = 0.0134500583693252
          // 4th order = 0.013630877683047651
          
          // spacing: 0.018 Å
          // 2nd order = 0.030957075842291584
          // 4th order = 0.03197474541714042
          
          // spacing: 0.020 Å
          // 2nd order = 0.035667597263968495
          // 4th order = 0.037020990097903966
          
          // 4th order: kinetic energy
          // spacing in Å
          // scaling law: KE = spacing^{1.50}
          //
          // 0.004 - 0.0035136492963466414
          // 0.006 - 0.006372689246770936
          // 0.008 - 0.009787292514539785
          // 0.010 - 0.013630877683047651
          // 0.012 - 0.017831284679967762
          // 0.014 - 0.022326506401555618
          // 0.016 - 0.027059174818914906
          // 0.018 - 0.031974745417140420
          // 0.020 - 0.037020990097903966
          // 0.030 - 0.06253649838896072
          // 0.040 - 0.08495735285971276
          // 0.050 - 0.10124387563313601
          // 0.060 - 0.11057718716294337
          // 0.070 - 0.11369516474119935
          // 0.080 - 0.11206056361881009
          // 0.090 - 0.10723632457812105
          // 0.100 - 0.10055459338968825
          //
          // external energy
          // spacing in Å
          // scaling law: 1 + PE = spacing^{2.00}
          //
          // 0.004 - -1.1149023690641116
          // 0.006 - -1.0202569947422298
          // 0.008 - -0.9986269854533549
          // 0.010 - -0.9917613397214031
          // 0.012 - -0.9870798312959288
          // 0.014 - -0.9825135314084877
          // 0.016 - -0.9773083403017427
          // 0.018 - -0.9714896067715426
          // 0.020 - -0.9650858099200509
          // 0.030 - -0.9253970250951384
          // 0.040 - -0.8760852995592328
          // 0.050 - -0.8214242605367826
          // 0.060 - -0.7650828379191089
          // 0.070 - -0.7097922183978944
          // 0.080 - -0.6573319397110133
          // 0.090 - -0.6086879637644945
          // 0.100 - -0.5642675116560891
          
          kineticEnergy += -0.5 * contribution / denominator
          
//          if Float.random(in: 0..<1) < 1e-4 {
//            print()
//            print("kinetic energy calculation:")
//            print("samples[0] =", samples[0])
//            print("samples[1] =", samples[1])
//            print("samples[2] =", samples[2])
//            print("cellWidth =", cellWidth)
//            print("contribution =", contribution)
//          }
        }
        kineticEnergy = kineticEnergy.magnitude
        
        // Create the external potential term.
        let address = (coords &* addressDeltas).wrappedSum()
        let fragment = fragments[address]
        let radius = (fragment.position * fragment.position).sum().squareRoot()
        let externalEnergy = -1 / radius
        
        // Create the Hartree term.
        let position = fragment.position
        var hartreeEnergyAccumulator: Double = .zero
//        for (i, densityStructure) in densities.enumerated() {
//          let otherPosition = SIMD3(densityStructure.x,
//                                    densityStructure.y,
//                                    densityStructure.z)
//          let cellWidth: Float = 0.020 / 0.0529177
//          var g: Float
//
//          if i == address {
//            // chelikowsky1994
//            g = -cellWidth * cellWidth
//            g *= Float.pi / 2 + 3 * logf((Float(3).squareRoot() - 1) /
//                                         (Float(3).squareRoot() + 1))
//          } else {
//            let delta = otherPosition - position
//            let distance = (delta * delta).sum().squareRoot()
//            let microvolume = cellWidth * cellWidth * cellWidth
//            g = microvolume / distance
//          }
//
//          let density = Float(densityStructure.w)
//          hartreeEnergyAccumulator += Double(density * g)
//        }
        let hartreeEnergy = Float(hartreeEnergyAccumulator)
        
        // Local density approximation.
//        let localDensity = densities[address].w
//        let exchangeEnergy = -cbrtf(3 / Float.pi * localDensity)
        let exchangeEnergy: Float = .zero
        
        // Sum all of the energies.
        let energy = kineticEnergy + externalEnergy + hartreeEnergy + exchangeEnergy
        hartreeψ[address].wavefunction *= hartreeEnergy
        exchangeψ[address].wavefunction *= exchangeEnergy
        kineticψ[address].wavefunction *= kineticEnergy
        externalψ[address].wavefunction *= externalEnergy
        energyψ[address].wavefunction *= energy
      }
    }
  }
  
  let hartree = dot(fragments, hartreeψ)
  let exchange = dot(fragments, exchangeψ)
  let kinetic = dot(fragments, kineticψ)
  let external = dot(fragments, externalψ)
  let hamiltonian = dot(fragments, energyψ)
  let sumEnergy = hartree + exchange + kinetic + external
  
  print()
  print("""
   ============ Energy (Hartree) ==============
   |   Hamiltonian         : \(hamiltonian)
   |   Sum Energy          : \(sumEnergy)
   |   "Energy"            : \(createEnergy(fragments: energyψ))
   --------------------------------------------
   | * Ion-ion Energy      : 0.0
   | * Eigenvals sum for 0 : 0
   | * Hartree Energy      : \(hartree)
   | * XC Energy           : \(exchange)
   | * Kinetic Energy      : \(kinetic)
   | * External Energy     : \(external)
   | * Non-local Energy    : 0
   ============================================
  """)
  
  return energyψ
}

// MARK: - Electron Rendering

func renderElectron(_ fragments: [OrbitalFragment]) -> [Entity] {
  var output: [Entity] = []
  for fragment in fragments {
    let cellWidth: Float = spacing / 0.0529177
    let microvolumeBohr3 = cellWidth * cellWidth * cellWidth
    let occupancy = fragment.wavefunction * fragment.wavefunction
    let chargeDensityBohr3 = occupancy / microvolumeBohr3
    let atomsPerNm3 = min(256, 16 * 300 * chargeDensityBohr3)
    
    let visualizationScale: Float = 2
    let microvolumeNm3 = microvolumeBohr3 * visualizationScale * visualizationScale * visualizationScale
    var atomsToGenerate = microvolumeNm3 * atomsPerNm3
    if atomsToGenerate < 0.5 {
      if Float.random(in: 0..<1) < atomsToGenerate {
        atomsToGenerate = 1
      }
    }
    
    var atomType: Element = .hydrogen
    var occupancyCutoff: Float = 1e-4 / 16
    occupancyCutoff *= pow(cellWidth / 0.09, 3)
    if occupancy > occupancyCutoff {
      atomType = .phosphorus
    } else if occupancy > occupancyCutoff / 4 {
      atomType = .nitrogen
    } else if occupancy > occupancyCutoff / 16 {
      atomType = .fluorine
    } else if occupancy > occupancyCutoff / 64 {
      atomType = .carbon
    }
    
    for _ in 0..<Int(atomsToGenerate.rounded(.toNearestOrEven)) {
      let range = -cellWidth/2..<cellWidth/2
      let offset = SIMD3<Float>.random(in: range)
      let positionBohr = fragment.position + offset
      let positionNm = positionBohr * visualizationScale
      
      if positionNm.z <= 0 {
        output.append(Entity(position: positionNm, type: .atom(atomType)))
      }
    }
  }
  
  return output
}
