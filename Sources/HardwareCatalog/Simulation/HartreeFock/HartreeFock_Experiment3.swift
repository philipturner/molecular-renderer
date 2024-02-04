//
//  HartreeFock_Experiment3.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 1/29/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Rewrite the code from scratch, again. This time, debug how the kinetic
  // energy of hydrogen ground-state orbitals is computed.
  // - Don't include the Hartree or exchange terms in the next code rewrite.
  //   Just the kinetic and external energy. Remove SCF iterations as well.
  // - This is still a single-electron system. We need to prove that the
  //   Schrodinger equation produces an orbital strongly reminiscent of the
  //   hydrogen 1s orbital.
  // - Introduce variable-resolution wave functions during this experiment to
  //   reduce the compute cost of high-accuracy tests.
  //
  // Procedure:
  // - Take an exact numerical integral at the finest possible grid width,
  //   create a mipmap, then resample at the centers of bins. Certain density
  //   thresholds will fail to be sampled.
  // - Store variable-resolution orbitals in Morton order, so you can
  //   orthogonalize them later without a special data structure.
  // - Find how deviation from true energy scales with uniform grid width or
  //   variable fragment count. Compare density threshold and minimum
  //   fragment size iso-accuracy.
  // - Compare constrained fragment count (density threshold) to actual fragment
  //   count, which will be larger.
  //
  // TODO: Establish an efficient data layout in a future experiment.
  // Already proved a substantial speedup by hand for 2D wavefunctions.
  // Making a data structure "right" requires careful planning to make it
  // efficient and GPU-friendly.
  // - This experiment can still prototype an "inefficient" data layout and
  //   achieve the goal of comparing uniform grids to variable resolution.
  // - Bonus if SCF convergence is demonstrated with variable resolution,
  //   modifying the fragments every iteration.
  
  var descriptor = WavefunctionDescriptor()
  descriptor.cellCountWidth = 128
  descriptor.gridWidthBohr = 25
  descriptor.quantumNumbers = QuantumNumbers(n: 1, l: 0, m: 0)
  let fragments = createWavefunction(descriptor: descriptor)
  
  var integral: Double = .zero
  for fragment in fragments {
    let value = fragment.wavefunction * fragment.wavefunction
    let microvolume = fragment.spacing * fragment.spacing * fragment.spacing
    integral += Double(value * microvolume)
  }
  print("integral:", integral)
  
  // Steps:
  // - Start measuring some observables like kinetic and external energy.
  // - Iteratively solve the Schrodinger equation like a self-consistent field
  //   equation on a uniform grid.
  // - Repeat the steps above with variable resolution.
  
  return renderElectron(fragments)
}

// MARK: - Wavefunction Initialization

struct OrbitalFragment {
  // Center of the fragment, in Bohr.
  var position: SIMD3<Float>
  
  // Spacing of the fragment, in Bohr.
  var spacing: Float
  
  // Value of the wavefunction at this point, normalized to spatial units of
  // Bohr.
  var wavefunction: Float
}

// A descriptor for a hydrogen wavefunction.
struct WavefunctionDescriptor {
  var cellCountWidth: Int?
  var gridWidthBohr: Float?
  var quantumNumbers: QuantumNumbers?
  // future options for enabling variable resolution and max probability
}

func createWavefunction(
  descriptor: WavefunctionDescriptor
) -> [OrbitalFragment] {
  var fragments: [OrbitalFragment] = []
  guard let cellCountWidth = descriptor.cellCountWidth,
        let gridWidthBohr = descriptor.gridWidthBohr,
        let quantumNumbers = descriptor.quantumNumbers else {
    fatalError("Incomplete descriptor.")
  }
  
  func traverseOctree(coordinates: SIMD3<Float>, radius: Float) {
    let lowerInvalid = coordinates - radius .>= Float(cellCountWidth) / 2
    let upperInvalid = coordinates + radius .<= -Float(cellCountWidth) / 2
    if any(lowerInvalid .| upperInvalid) {
      return
    }
    
    if radius < 1 {
      let spacing = gridWidthBohr / Float(cellCountWidth)
      let position = coordinates * spacing
      let coordinates = SphericalCoordinates(cartesian: position)
      let wavefunction = hydrogenWaveFunction(
        numbers: quantumNumbers, coordinates: coordinates)
      
      fragments.append(OrbitalFragment(
        position: position,
        spacing: spacing,
        wavefunction: wavefunction))
    } else {
      @_transparent func traverse(_ permutation: SIMD3<Int8>) {
        let nextRadius = radius / 2
        traverseOctree(
          coordinates: coordinates + SIMD3<Float>(permutation) * nextRadius,
          radius: nextRadius)
      }
      
      traverse(SIMD3(-1, -1, -1))
      traverse(SIMD3( 1, -1, -1))
      traverse(SIMD3(-1,  1, -1))
      traverse(SIMD3( 1,  1, -1))
      traverse(SIMD3(-1, -1,  1))
      traverse(SIMD3( 1, -1,  1))
      traverse(SIMD3(-1,  1,  1))
      traverse(SIMD3( 1,  1,  1))
    }
  }
  
  traverseOctree(coordinates: .zero, radius: 1024 * 1024)
  return fragments
}

// MARK: - Hydrogen Wave Function

func laguerrePolynomial(
  alpha: Float, n: Int
) -> (_ x: Float) -> Float {
  if n == 0 {
    return { _ in 1 }
  } else if n == 1 {
    return { x in 1 + alpha - x }
  } else if n >= 1 {
    return { x in
      var stack: [Float] = []
      stack.append(1)
      stack.append(1 + alpha - x)
      
      for k in 1...(n - 1) {
        let coeffLeft = Float(2 * k + 1) + alpha - x
        let coeffRight = -(Float(k) + alpha)
        let numerator = coeffLeft * stack[k] + coeffRight * stack[k - 1]
        let denominator = Float(k + 1)
        stack.append(numerator / denominator)
      }
      return stack.last!
    }
  }
  
  fatalError("Unsupported value for n.")
}

func sphericalHarmonic(
  l: Int, m: Int
) -> (_ theta: Float, _ phi: Float) -> Float {
  if l == 0 {
    if m == 0 {
      return { _, _ in
        1.0 / 2 * (1 / Float.pi).squareRoot()
      }
    }
  } else if l == 1 {
    if m == 0 {
      return { theta, _ in
        1.0 / 2 * (3 / Float.pi).squareRoot() * Float.cos(theta)
      }
    }
  }
  
  fatalError("Unsupported value for m or l.")
}

func factorial(_ x: Int) -> Int {
  guard x >= 0 else {
    fatalError("Cannot take factorial of negative number.")
  }
  if x == 0 {
    return 1
  } else {
    var output = x
    var counter = x - 1
    while counter > 0 {
      output *= counter
      counter -= 1
    }
    return output
  }
}

struct QuantumNumbers {
  var n: Int
  var l: Int
  var m: Int
}

struct SphericalCoordinates {
  var r: Float
  var phi: Float
  var theta: Float
  
  init(cartesian: SIMD3<Float>) {
    r = (cartesian * cartesian).sum().squareRoot()
    if r.magnitude < .leastNormalMagnitude {
      phi = 0
      theta = 0
    } else {
      // in the physics convention, phi is theta and theta is phi
      phi = Float.atan2(y: cartesian.y, x: cartesian.x)
      theta = Float.acos(cartesian.z / r)
    }
  }
}

func hydrogenWaveFunction(
  numbers: QuantumNumbers,
  coordinates: SphericalCoordinates
) -> Float {
  let R = { (r: Float) -> Float in
    let numerator = factorial(numbers.n - numbers.l - 1)
    let denominator = 2 * numbers.n * factorial(numbers.n + numbers.l)
    var normalizationFactor = Float(numerator) / Float(denominator)
    
    let Z: Float = 1
    let shellPart = Float(2 * Z) / Float(numbers.n)
    normalizationFactor *= shellPart * shellPart * shellPart
    normalizationFactor.formSquareRoot()
    
    let shellRadiusPart = shellPart * r
    let L = laguerrePolynomial(
      alpha: Float(2 * numbers.l + 1),
      n: numbers.n - numbers.l - 1)
    
    return normalizationFactor
    * exp(-shellRadiusPart / 2)
    * pow(shellRadiusPart, Float(numbers.l))
    * L(shellRadiusPart)
  }
  
  let Y = sphericalHarmonic(l: numbers.l, m: numbers.m)
  let magnitude = R(coordinates.r) * Y(coordinates.theta, coordinates.phi)
  let parity = pow(-1, Float(numbers.l))
  return parity * magnitude
}

// MARK: - Rendering

func renderElectron(_ fragments: [OrbitalFragment]) -> [Entity] {
  var output: [Entity] = []
  for fragment in fragments {
    let microvolume = fragment.spacing * fragment.spacing * fragment.spacing
    let chargeDensity = fragment.wavefunction * fragment.wavefunction
    let atomsPerNm3 = min(256, 64 * 300 * chargeDensity)
    
    let scale: Float = 1
    let microvolumeNm3 = microvolume * scale * scale * scale
    var atomsToGenerate = Int((microvolumeNm3 * atomsPerNm3).rounded(.down))
    let remainder = microvolumeNm3 * atomsPerNm3 - Float(atomsToGenerate)
    if Float.random(in: 0..<1) < remainder {
      atomsToGenerate += 1
    }
    
    for _ in 0..<atomsToGenerate {
      let range = -fragment.spacing/2..<fragment.spacing/2
      let offset = SIMD3<Float>.random(in: range)
      let positionBohr = fragment.position + offset
      let positionNm = positionBohr * scale
      output.append(Entity(position: positionNm, type: .atom(.hydrogen)))
    }
  }
  
  return output
}

// MARK: - Operators

func kinetic(_ fragments: [OrbitalFragment]) -> [Float] {
  // Generate a data structure that can direct any requests for a variable-
  // resolution 3D lookup, just by exploiting Morton order. It doesn't have to
  // be efficient. This experiment could generate insights for the invention of
  // an efficient layout.
  //
  // Change so the original data structure has a few tiers. Each one is bounded
  // by a cuboid in real space. It is stored like a traditional mipmap,
  // facilitating multigrid calculations. The resolution of cells is adjusted
  // during multigrid V-cycles.
  fatalError("Not implemented.")
}

