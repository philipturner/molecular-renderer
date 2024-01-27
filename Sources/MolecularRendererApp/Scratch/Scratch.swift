// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

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

func createGeometry() -> [[Entity]] {
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
  for zIndex in -15..<15 {
    for yIndex in -15..<15 {
      for xIndex in -15..<15 {
        var position = SIMD3<Float>(
          Float(xIndex),
          Float(yIndex),
          Float(zIndex))
        position += 0.5
        position *= 0.020
        position /= 0.0529177
        
        // 1s orbital of hydrogen.
        let Z: Float = 1
        let r: Float = (position * position).sum().squareRoot()
        let n: Float = 1
        let a: Float = 1
        var wavefunction = exp(-Z * r / (n * a)) * (2 * Z * r / (n * a))
        wavefunction /= r
        
//        let l: Float = 0
//        let alpha = 2 * l + 1
//        let L_1 = 1 + alpha - r
//        wavefunction *= L_1
        
//        wavefunction += 0.1 * position.y.magnitude
        
        let fragment = OrbitalFragment(
          position: position, wavefunction: wavefunction)
        fragments.append(fragment)
      }
    }
  }
  fragments = normalize(fragments: fragments)
  var previousDensity = createDensity(fragments: fragments)
  
  var output: [[Entity]] = []
  for frameID in 0..<15 {
    if frameID > 0 {
      let nextPreviousDensity = createDensity(fragments: fragments)
      let energyψ = hamiltonian(
        fragments: fragments,
        previousDensity: previousDensity)
      
      let ψ = normalize(fragments: energyψ)
      fragments = ψ
      previousDensity = nextPreviousDensity
    }
    
    let rendered = renderElectron(fragments)
    for _ in 0..<30 {
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
    let cellWidth: Float = 0.020 / 0.0529177
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
  
  for zIndex in -15..<15 {
    for yIndex in -15..<15 {
      for xIndex in -15..<15 {
        let coords = 15 &+ SIMD3(xIndex, yIndex, zIndex)
        let addressDeltas = SIMD3<Int>(1, 30, 30 * 30)
        
        // Create the kinetic energy term.
        var divergence: Float = 0
        for laneID in 0..<3 {
          var coordsDelta = SIMD3<Int>.zero
          coordsDelta[laneID] = 1
          let lowerCoords = coords &- coordsDelta
          let upperCoords = coords &+ coordsDelta
          let coordsArray = [lowerCoords, coords, upperCoords]
          
          var samples: SIMD3<Float> = .zero
          for (i, coordsElement) in coordsArray.enumerated() {
            guard all(coordsElement .>= 0), all(coordsElement .< 30) else {
              continue
            }
            let address = (coordsElement &* addressDeltas).wrappedSum()
            samples[i] = fragments[address].wavefunction
          }
          
          let cellWidth: Float = 0.020 / 0.0529177
          let lowerDerivative = (samples[1] - samples[0]) / cellWidth
          let upperDerivative = (samples[2] - samples[1]) / cellWidth
          divergence += (upperDerivative - lowerDerivative) / cellWidth
        }
        let kineticEnergy = -0.5 * divergence
        
        // Create the external potential term.
        let address = (coords &* addressDeltas).wrappedSum()
        let fragment = fragments[address]
        let radius = (fragment.position * fragment.position).sum().squareRoot()
        let externalEnergy = -1 / radius
        
        // Create the Hartree term.
        let position = fragment.position
        var hartreeEnergyAccumulator: Double = .zero
        for (i, densityStructure) in densities.enumerated() {
          let otherPosition = SIMD3(densityStructure.x,
                                    densityStructure.y,
                                    densityStructure.z)
          let cellWidth: Float = 0.020 / 0.0529177
          var g: Float
          
          if i == address {
            // chelikowsky1994
            g = -cellWidth * cellWidth
            g *= Float.pi / 2 + 3 * logf((Float(3).squareRoot() - 1) /
                                         (Float(3).squareRoot() + 1))
          } else {
            let delta = otherPosition - position
            let distance = (delta * delta).sum().squareRoot()
            let microvolume = cellWidth * cellWidth * cellWidth
            g = microvolume / distance
          }
          
          let density = Float(densityStructure.w)
          hartreeEnergyAccumulator += Double(density * g)
        }
        let hartreeEnergy = Float(hartreeEnergyAccumulator)
        
        // Local density approximation.
        let localDensity = densities[address].w
        let exchangeEnergy = -cbrtf(3 / Float.pi * localDensity)
        
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
    let cellWidth: Float = 0.020 / 0.0529177
    let microvolumeBohr3 = cellWidth * cellWidth * cellWidth
    let occupancy = fragment.wavefunction * fragment.wavefunction
    let chargeDensityBohr3 = occupancy / microvolumeBohr3
    let atomsPerNm3 = min(256, 64 * 300 * chargeDensityBohr3)
    
    let visualizationScale: Float = 2
    let microvolumeNm3 = microvolumeBohr3 * visualizationScale * visualizationScale * visualizationScale
    var atomsToGenerate = microvolumeNm3 * atomsPerNm3
    if atomsToGenerate < 0.5 {
      if Float.random(in: 0..<1) < atomsToGenerate {
        atomsToGenerate = 1
      }
    }
    
    var atomType: Element = .hydrogen
    var occupancyCutoff: Float = 1e-4 / 64
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
