// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

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
  
  let cellCountWidth: Int = 180
  let gridWidthBohr: Float = 6
  
  var fragments: [OrbitalFragment] = []
  for zIndex in -cellCountWidth/2..<cellCountWidth/2 {
    for yIndex in -cellCountWidth/2..<cellCountWidth/2 {
      for xIndex in -cellCountWidth/2..<cellCountWidth/2 {
        let spacing = gridWidthBohr / Float(cellCountWidth)
        var position = SIMD3<Float>(
          Float(xIndex) + 0.5,
          Float(yIndex) + 0.5,
          Float(zIndex) + 0.5)
        position *= spacing
        
        let numbers = QuantumNumbers(n: 1, l: 0, m: 0)
        let coordinates = SphericalCoordinates(cartesian: position)
        let wavefunction = hydrogenWaveFunction(
          numbers: numbers, coordinates: coordinates)
        
        fragments.append(OrbitalFragment(
          position: position,
          spacing: spacing,
          wavefunction: wavefunction))
      }
    }
  }
  
  print(fragments.count)
  
  exit(0)
}

struct OrbitalFragment {
  // Center of the fragment, in Bohr.
  var position: SIMD3<Float>
  
  // Spacing of the fragment, in Bohr.
  var spacing: Float
  
  // Value of the wavefunction at this point, normalized to spatial units of
  // Bohr.
  var wavefunction: Float
}

// MARK: - Hydrogen Wave Function

func laguerrePolynomial(
  alpha: Float, n: Int
) -> (_ x: Float) -> Float {
  guard n == 0 || n == 1 else {
    fatalError("Unsupported value for n.")
  }
  if n == 0 {
    return { _ in 1 }
  } else {
    return { x in 1 + alpha - x }
  }
}

func sphericalHarmonic(
  l: Int, m: Int
) -> (_ theta: Float, _ phi: Float) -> Float {
  guard m == 0, l == 0 else {
    fatalError("Unsupported value for m or l.")
  }
  return { _, _ in
    1.0 / 2 * (1 / Float.pi).squareRoot()
  }
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
  var theta: Float
  var phi: Float
  
  init(cartesian: SIMD3<Float>) {
    r = (cartesian * cartesian).sum().squareRoot()
    if r.magnitude < .leastNormalMagnitude {
      theta = 0
      phi = 0
    } else {
      theta = Float.atan2(y: cartesian.y, x: cartesian.x)
      phi = Float.acos(cartesian.z / r)
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
  return R(coordinates.r) * Y(coordinates.theta, coordinates.phi)
}
