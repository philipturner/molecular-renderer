//
//  PlayerState.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/18/23.
//

import Foundation
import Numerics
import simd

fileprivate let defaultPlayerPosition: SIMD3<Float> = [0, 0, 1]

struct PlayerState {
  static let historyLength: Int = 3
  
  // Player position in nanometers.
  var position: SIMD3<Float> = defaultPlayerPosition
  
  // The orientation of the camera or the player in revolutions
  var orientationHistory: RingBuffer = .init(
    repeating: Orientation(azimuth: 0, zenith: 0.25), count: historyLength)
  
  // Use azimuth * zenith to get the correct orientation from Minecraft.
  var rotations: (azimuth: simd_float3x3, zenith: simd_float3x3) {
    // Assume that the world space axes are x, y, z and the camera space axes
    // are u, v, w
    // Assume that the azimuth angle is a and the zenith angle is b
    // Assume that the ray direction in world space is r = (rx, ry, rz) and in
    // camera space is s = (su, sv, sw)

    // The transformation matrix can be obtained by multiplying two rotation
    // matrices: one for azimuth and one for zenith
    // The azimuth rotation matrix rotates the world space axes around the
    // y-axis by -a radians
    // The zenith rotation matrix rotates the camera space axes around the
    // u-axis by -b radians
    
    var (azimuth, zenith) = orientationHistory.load().phase
    azimuth = -azimuth
    zenith = zenith - 0.25
    
    let x: SIMD2<Double> = .init(azimuth, zenith) * 2
    var sinvals: SIMD2<Double> = .zero
    var cosvals: SIMD2<Double> = .zero
    _simd_sincospi_d2(x, &sinvals, &cosvals)
    
    let sina = Float(sinvals[0])
    let cosa = Float(cosvals[0])
    let sinb = Float(sinvals[1])
    let cosb = Float(cosvals[1])
    
    // The azimuth rotation matrix is:
    let M_a = simd_float3x3(SIMD3(cosa, 0, sina),
                            SIMD3(0, 1, 0),
                            SIMD3(-sina, 0, cosa))
      .transpose // simd and Metal use the column-major format

    // The zenith rotation matrix is:
    let M_b = simd_float3x3(SIMD3(1, 0, 0),
                            SIMD3(0, cosb, -sinb),
                            SIMD3(0, sinb, cosb))
      .transpose // simd and Metal use the column-major format
    
    return (azimuth: M_a, zenith: M_b)
  }
  
  // FOV dilation due to sprinting.
  func fovDegrees(progress: Float) -> Float {
    return simd_mix(90, 90 * 1.20, progress)
  }
  
  static func makeRotation(azimuth: Double) -> simd_float3x3 {
    let x: SIMD2<Double> = .init(azimuth / .pi, 0)
    var sinvals: SIMD2<Double> = .zero
    var cosvals: SIMD2<Double> = .zero
    _simd_sincospi_d2(x, &sinvals, &cosvals)
    
    let sina = Float(sinvals[0])
    let cosa = Float(cosvals[0])
    let sinb = Float(sinvals[1])
    let cosb = Float(cosvals[1])
    
    // The azimuth rotation matrix is:
    let M_a = simd_float3x3(SIMD3(cosa, 0, sina),
                            SIMD3(0, 1, 0),
                            SIMD3(-sina, 0, cosa))
      .transpose // simd and Metal use the column-major format

    // The zenith rotation matrix is:
    let M_b = simd_float3x3(SIMD3(1, 0, 0),
                            SIMD3(0, cosb, -sinb),
                            SIMD3(0, sinb, cosb))
      .transpose // simd and Metal use the column-major format
    
    return M_a * M_b
  }
  
  /// Accepts the azimuth and zenith in revolutions, returning a rotation
  /// matrix.
  ///
  /// - parameter azimuth: Rotation counterclockwise around the world-space
  ///   Y axis, where 0 is looking straight ahead.
  /// - parameter zenith: Rotation counterclockwise around the camera-space
  ///   U axis, where 0 is looking straight down. Must be between -0.25 and 0.25,
  ///   otherwise there will be an error.
  static func rotation(azimuth: Float, zenith: Float) -> (
    SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
  ) {
    guard zenith >= -0.25 && zenith <= 0.25 else {
      fatalError("Invalid zenith.")
    }
    let quaternionU = Quaternion<Float>(
      angle: zenith * 2 * .pi, axis: [1, 0, 0])
    let quaternionY = Quaternion<Float>(
      angle: azimuth * 2 * .pi, axis: [0, 1, 0])
    
    var basis1 = quaternionU.act(on: [1, 0, 0])
    var basis2 = quaternionU.act(on: [0, 1, 0])
    var basis3 = quaternionU.act(on: [0, 0, 1])
    basis1 = quaternionY.act(on: basis1)
    basis2 = quaternionY.act(on: basis2)
    basis3 = quaternionY.act(on: basis3)
    return (basis1, basis2, basis3)
  }
}


// Stores the azimuth's multiple of 2 * pi separately from the phase. This
// preserves the dynamic range without interfering with the averaging process.
// Limits the zenith to a range between 0 and pi radians to prevent flipping.
struct Orientation {
  // All angles are stored in units of revolutions.
  private var azimuthQuotient: Int
  private var azimuthRemainder: Double
  private var zenith: Double // clamped to (0, pi)
  
  // Enter azimuth and zenith in revolutions, not radians.
  init(azimuth: Double, zenith: Double) {
    self.azimuthQuotient = 0
    self.azimuthRemainder = azimuth
    self.zenith = zenith
    
    // The inputs might not be within the desired range.
    self.normalize()
  }
  
  // Average several angles, while preserving the quotient.
  init(averaging orientations: [Orientation]) {
    self.azimuthQuotient = 0
    self.azimuthRemainder = 0
    self.zenith = 0
    
    for orientation in orientations {
      azimuthQuotient += orientation.azimuthQuotient
      azimuthRemainder += orientation.azimuthRemainder
      zenith += orientation.zenith
    }
    
    // Re-normalizing here won't fix the loss of mantissa information, but it
    // will erroneously clamp the sum of zeniths.
    let sizeReciprocal = recip(Double(orientations.count))
    var temp_azimuth = Double(self.azimuthQuotient)
    temp_azimuth *= sizeReciprocal
    self.azimuthRemainder *= sizeReciprocal
    self.zenith *= sizeReciprocal
    
    let quotient = temp_azimuth.rounded(.down)
    let remainder = temp_azimuth - quotient
    self.azimuthQuotient = Int(quotient)
    self.azimuthRemainder += remainder
    
    // Re-normalize after averaging the angles.
    self.normalize()
  }
  
  mutating func normalize() {
    let floor = azimuthRemainder.rounded(.down)
    self.azimuthQuotient += Int(floor)
    self.azimuthRemainder = azimuthRemainder - floor
    self.zenith = simd_clamp(zenith, 0, 0.5)
  }
  
  mutating func add(azimuth: Double, zenith: Double) {
    self.azimuthRemainder += azimuth
    self.zenith += zenith
    
    // Re-normalize after changing the angles.
    self.normalize()
  }
  
  var phase: (azimuth: Double, zenith: Double) {
    return (self.azimuthRemainder, self.zenith)
  }
}

