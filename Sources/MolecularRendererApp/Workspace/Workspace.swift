import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Rods (show skeleton of 2-bit HA)
// Patterns (show one rod in detail)
// Drive walls (show before and after actuation)
// Drive walls (GIF)
// Housing (show housing and drive walls, without logic rods inside)
//
// Upload images to GDrive

func createGeometry() -> [[Entity]] {
  let halfAdder = HalfAdder()
  
  var frames: [[Entity]] = []
  for frameID in 0..<240 {
    var rod1 = halfAdder.intermediateUnit.propagate[0]
    var rod2 = halfAdder.intermediateUnit.propagate[1]
    var driveWall = halfAdder.intermediateUnit.driveWall
    
    var progress: Double = .zero
    if frameID < 60 {
      progress = Double(frameID) / 59
    } else if frameID < 120 {
      progress = 1
    } else if frameID < 180 {
      progress = Double(179 - frameID) / 59
    }
    
    rod1.rigidBody.centerOfMass.x += progress * 3.25 * 0.3567
    rod2.rigidBody.centerOfMass.x += progress * 3.25 * 0.3567
    rod1.rigidBody.centerOfMass.x -= 0.080
    rod2.rigidBody.centerOfMass.x -= 0.080
    driveWall.rigidBody.centerOfMass.y += progress * 3.25 * 0.3567
    
    var rigidBodies: [MM4RigidBody] = []
    rigidBodies.append(rod1.rigidBody)
    rigidBodies.append(rod2.rigidBody)
    rigidBodies.append(driveWall.rigidBody)
    
    func createFrame(rigidBodies: [MM4RigidBody]) -> [Entity] {
      var atoms: [Entity] = []
      for rigidBody in rigidBodies {
        for atomID in rigidBody.parameters.atoms.indices {
          let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
          let position = rigidBody.positions[atomID]
          let storage = SIMD4(position, Float(atomicNumber))
          atoms.append(Entity(storage: storage))
        }
      }
      return atoms
    }
    var frame = createFrame(rigidBodies: rigidBodies)
    
    // Reposition the scene, so the user doesn't have to move.
    let shift: Float = -5
    for atomID in frame.indices {
      var atom = frame[atomID]
      atom.position = SIMD3(-atom.position.x, atom.position.y, -atom.position.z)
      atom.position += SIMD3(7.7, -3.55, -2 + shift)
      frame[atomID] = atom
    }
    
    // Filter out atoms with a certain coordinate.
    var newFrame: [Entity] = []
    for atom in frame {
      if atom.position.z > -3 + shift {
        continue
      }
      newFrame.append(atom)
    }
    frames.append(newFrame)
  }
  
  return frames
}

// MARK: - Offline Rendering

//
//  OfflineRendering.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/4/24.
//

import CairoGraphics
import Foundation
import GIF
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func renderOffline(renderingEngine: MRRenderer) {
  struct Provider: MRAtomProvider {
    var atomFrames: [[Entity]] = []
    
    init() {
      atomFrames = createGeometry()
    }
    
    func atoms(time: MolecularRenderer.MRTime) -> [MolecularRenderer.MRAtom] {
      var frameID = time.absolute.frames
      frameID = max(frameID, 0)
      frameID = min(frameID, atomFrames.count - 1)
      
      let atomFrame = atomFrames[frameID]
      return atomFrame.map {
        MRAtom(origin: $0.position, element: $0.atomicNumber)
      }
    }
  }
  
  // Set up the renderer.
  let atomProvider = Provider()
  renderingEngine.setAtomProvider(atomProvider)
  renderingEngine.setQuality(
    MRQuality(minSamples: 7, maxSamples: 32, qualityCoefficient: 100))
  
  let position: SIMD3<Float> = .init(0, 0, 1)
  let rotation: (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>
  ) = (
    SIMD3(1, 0, 0),
    SIMD3(0, 1, 0),
    SIMD3(0, 0, 1)
  )
  renderingEngine.setCamera(
    MRCamera(position: position, rotation: rotation, fovDegrees: 30))
  renderingEngine.setLights([
    MRLight(origin: position, diffusePower: 1, specularPower: 1)
  ])
  
  // Render to GIF.
  let renderSemaphore: DispatchSemaphore = .init(value: 0)
  let renderQueue = DispatchQueue(label: "renderQueue")
  var gif = GIF(width: 360, height: 320)
  
  let checkpoint0 = Date()
  for frameID in 0..<atomProvider.atomFrames.count / 3 {
    print("rendering frame:", frameID * 3)
    
    var pixelBuffer = [UInt16](repeating: 0, count: 4 * 360 * 320)
    
    for offset in 0..<3 {
      let time = MRTime(absolute: frameID * 3 + offset, relative: 1, frameRate: 120)
      renderingEngine.setTime(time)
      renderingEngine.render { pixels in
        for pixelID in 0..<4 * 360 * 320 {
          pixelBuffer[pixelID] &+= UInt16(pixels[pixelID])
        }
        renderSemaphore.signal()
      }
      renderSemaphore.wait()
    }
    
    let image = try! CairoImage(width: 360, height: 320)
    for y in 0..<320 {
      for x in 0..<360 {
        let address = y * 360 + x
        let r = pixelBuffer[4 * address + 0]
        let g = pixelBuffer[4 * address + 1]
        let b = pixelBuffer[4 * address + 2]
        let a = pixelBuffer[4 * address + 3]
        
        let pixelVector16 = SIMD4(r, g, b, a)
        let pixelVector8 = SIMD4<UInt8>(truncatingIfNeeded: pixelVector16 / 3)
        let pixelScalar = unsafeBitCast(pixelVector8, to: UInt32.self)
        let color = Color(argb: pixelScalar)
        image[y, x] = color
      }
    }
    
    let quantization = OctreeQuantization(fromImage: image)
    let frame = Frame(
      image: image,
      delayTime: 3, // 33.3 FPS
      localQuantization: quantization)
    gif.frames.append(frame)
  }
  
  let checkpoint1 = Date()
  
  print("encoding GIF")
  let data = try! gif.encoded()
  print("encoded size")
  print(data.count)
  
  let checkpoint2 = Date()
  
  print("saving to file")
  let path = "/Users/philipturner/Desktop/Render.gif"
  let url = URL(fileURLWithPath: path)
  guard FileManager.default.createFile(atPath: path, contents: data) else {
    fatalError("Could not create file at \(url.relativeString).")
  }
  
  let checkpoint3 = Date()
  
  print()
  print("latency overview:")
  print("- checkpoint 0 -> 1 | \(checkpoint1.timeIntervalSince(checkpoint0))")
  print("- checkpoint 1 -> 2 | \(checkpoint2.timeIntervalSince(checkpoint1))")
  print("- checkpoint 2 -> 3 | \(checkpoint3.timeIntervalSince(checkpoint2))")
  
  exit(0)
}
