// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  for Z in 1...118 {
    let occupations = createShellOccupations(Z: Z)
    let effectiveCharges = createEffectiveCharges(
      Z: Z, occupations: occupations)
    
    var expectationRadii: [Float] = []
    for n in occupations.indices where n > 0 {
      let quantumNumbers = QuantumNumbers(n: n, l: 0, m: 0)
      let position = SIMD3<Float>(1, 0, 0)
      
      let waveFunction = hydrogenWaveFunction(
        Z: effectiveCharges[n],
        numbers: quantumNumbers,
        position: position)
      expectationRadii.append(waveFunction * 1 * waveFunction)
    }
    
    print("Z=\(Z), occupations=\(occupations), radii=\(expectationRadii)")
  }
  exit(0)
}

// MARK: - Hydrogen Wave Function

func laguerrePolynomial(
  alpha: Float, n: Int
) -> (_ x: Float) -> Float {
  if n == 0 {
    return { _ in 1 }
  } else if n > 0 {
    return { x in
      var secondLast: Float = 1
      var last: Float = 1 + alpha - x
      
      for k in 1..<n {
        let coeffLeft = Float(2 * k + 1) + alpha - x
        let coeffRight = -(Float(k) + alpha)
        let numerator = coeffLeft * last + coeffRight * secondLast
        let denominator = Float(k + 1)
        secondLast = last
        last = numerator / denominator
      }
      return last
    }
  }
  
  fatalError("Unsupported value for n.")
}

func cubicHarmonic(
  l: Int, m: Int
) -> (_ x: Float, _ y: Float, _ z: Float, _ r: Float) -> Float {
  var factorial: Int = 1
  for i in 0...l {
    factorial *= (i * 2 + 1)
  }
  let Nc = (Float(factorial) / (4 * Float.pi)).squareRoot()
  
  if l == 0 {
    return { _, _, _, _ in
      var output = Nc
      switch m {
      case 0: output *= 1
      default: fatalError("Invalid value for m.")
      }
      return output
    }
  } else if l == 1 {
    return { x, y, z, r in
      var output = Nc / r
      switch m {
      case 0: output *= z
      case -1: output *= x
      case 1: output *= y
      default: fatalError("Invalid value for m.")
      }
      return output
    }
  } else if l == 2 {
    return { x, y, z, r in
      var output = Nc / (r * r)
      switch m {
      case 0: output *= (3 * z * z - r * r) / (2 * Float(3).squareRoot())
      case -1: output *= x * z
      case 1: output *= y * z
      case -2: output *= x * y
      case 2: output *= (x * x - y * y) / 2
      default: fatalError("Invalid value for m.")
      }
      return output
    }
  } else if l == 3 {
    return { x, y, z, r in
      var output = Nc / (r * r * r)
      switch m {
      case 0:
        output *= z * (2 * z * z - 3 * x * x - 3 * y * y)
        output /= 2 * Float(15).squareRoot()
      case -1:
        output *= x * (4 * z * z - x * x - y * y)
        output /= 2 * Float(10).squareRoot()
      case 1:
        output *= y * (4 * z * z - x * x - y * y)
        output /= 2 * Float(10).squareRoot()
      case -2:
        output *= x * y * z
      case 2:
        output *= z * (x * x - y * y) / 2
      case -3:
        output *= x * (x * x - 3 * y * y)
        output /= 2 * Float(6).squareRoot()
      case 3:
        output *= y * (3 * x * x - y * y)
        output /= 2 * Float(6).squareRoot()
      default:
        fatalError("Invalid value for m.")
      }
      return output
    }
  }
  
  fatalError("Unsupported value for l.")
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

func hydrogenWaveFunction(
  Z: Float,
  numbers: QuantumNumbers,
  position: SIMD3<Float>
) -> Float {
  let R = { (r: Float) -> Float in
    let numerator = factorial(numbers.n - numbers.l - 1)
    let denominator = 2 * numbers.n * factorial(numbers.n + numbers.l)
    var normalizationFactor = Float(numerator) / Float(denominator)
    
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
  
  let r = (position * position).sum().squareRoot()
  let Y = cubicHarmonic(l: numbers.l, m: numbers.m)
  let magnitude = R(r) * Y(position.x, position.y, position.z, r)
  let parity = pow(-1, Float(numbers.l))
  return parity * magnitude
}

// MARK: - Ansatz

func createShellOccupations(Z: Int) -> [Int] {
  // Output is zero-indexed, starting with the nonexistent zero shell. It spans
  // from n=0 to n=7.
  var shellOccupations = [Int](repeating: 0, count: 1 + 7)
  
  var cursorZ: Int = 0
  func subShell(n: Int, occupancy: Int) {
    if Z > cursorZ {
      shellOccupations[n] += min(Z - cursorZ, occupancy)
    }
    cursorZ += occupancy
  }
  
  // First period.
  subShell(n: 1, occupancy: 2)
  
  // Second period.
  subShell(n: 2, occupancy: 2)
  subShell(n: 2, occupancy: 6)
  
  // Third period.
  subShell(n: 3, occupancy: 2)
  subShell(n: 3, occupancy: 6)
  
  // Fourth period.
  subShell(n: 4, occupancy: 2)
  subShell(n: 3, occupancy: 10)
  subShell(n: 4, occupancy: 6)
  
  // Fifth period.
  subShell(n: 5, occupancy: 2)
  subShell(n: 4, occupancy: 10)
  subShell(n: 5, occupancy: 6)
  
  // Sixth period.
  subShell(n: 6, occupancy: 2)
  subShell(n: 4, occupancy: 14)
  subShell(n: 5, occupancy: 10)
  subShell(n: 6, occupancy: 6)
  
  // Seventh period.
  subShell(n: 7, occupancy: 2)
  subShell(n: 5, occupancy: 14)
  subShell(n: 6, occupancy: 10)
  subShell(n: 7, occupancy: 6)
  
  // Eighth period.
  if Z > 118 {
    fatalError("Eighth period elements are not supported.")
  }
  
  return shellOccupations
}

// Returns the effective charge for each electron shell.
func createEffectiveCharges(Z: Int, occupations: [Int]) -> [Float] {
// var correction = Float(n) * Float(n) / Float(Zeff)
// correction = correction.squareRoot()
// var normalization = correction * correction * correction
// normalization = normalization.squareRoot()
   
  var coreCharge = Z
  var effectiveCharges: [Float] = []
  for occupation in occupations {
    effectiveCharges.append(Float(coreCharge))
    coreCharge -= occupation
  }
  return effectiveCharges
}
