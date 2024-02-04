// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
//  let polynomial = laguerrePolynomial(alpha: 0, n: 2)
//  let x: Float = 3.5
//  print(polynomial(x))
//  print(0.5 * (x * x - 4 * x + 2))
  
  let numbers = QuantumNumbers(n: 3, l: 0, m: 0, Z: 1)
  var integral: Double = .zero
  var radius: Double = .zero
  while radius < 300 {
    let dr: Double = 0.1
    defer { radius += dr }
    
    let coordinates = SphericalCoordinates(
      cartesian: SIMD3(Float(radius), 0, 0))
    let waveFunction = Double(hydrogenWaveFunction(
      numbers: numbers, coordinates: coordinates))
    
    let observable: Double = waveFunction * radius * waveFunction
    integral += observable * radius * radius * dr
  }
  integral *= 4 * Double.pi
  print(integral)
  exit(0)
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
  var Z: Int
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
    
    let shellPart = Float(2 * numbers.Z) / Float(numbers.n)
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
