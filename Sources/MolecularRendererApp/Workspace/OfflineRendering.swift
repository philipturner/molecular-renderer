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

func createAtomFrames(
  rigidBodyFrames: [[MM4RigidBody]]
) -> [[Entity]] {
  rigidBodyFrames.map { rigidBodies in
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
}

func createGeometry() -> [[Entity]] {
  let rigidBodyFrames = createRigidBodyFrames()
  let atomFrames = createAtomFrames(rigidBodyFrames: rigidBodyFrames)
  return atomFrames
}

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
  
  let position: SIMD3<Float> = .init(15, 3, 40)
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
    MRCamera(position: position, rotation: rotation, fovDegrees: 60))
  renderingEngine.setLights([
    MRLight(origin: position, diffusePower: 1, specularPower: 1)
  ])
  
  // Render to GIF.
  let renderSemaphore: DispatchSemaphore = .init(value: 3)
  let renderQueue = DispatchQueue(label: "renderQueue")
  var gif = GIF(width: 1280, height: 720)
  
  let checkpoint0 = Date()
  for frameID in 0..<atomProvider.atomFrames.count {
    print("rendering frame:", frameID)
    renderSemaphore.wait()
    
    let time = MRTime(absolute: frameID, relative: 1, frameRate: 60)
    renderingEngine.setTime(time)
    renderingEngine.render { pixels in
      let image = try! CairoImage(width: 1280, height: 720)
      for y in 0..<720 {
        for x in 0..<1280 {
          let address = y * 1280 + x
          let r = pixels[4 * address + 0]
          let g = pixels[4 * address + 1]
          let b = pixels[4 * address + 2]
          let a = pixels[4 * address + 3]
          
          let pixelVector = SIMD4(r, g, b, a)
          let pixelScalar = unsafeBitCast(pixelVector, to: UInt32.self)
          let color = Color(argb: pixelScalar)
          image[y, x] = color
        }
      }
      
      let quantization = OctreeQuantization(fromImage: image)
      let frame = Frame(
        image: image,
        delayTime: 2, // 50 FPS
        localQuantization: quantization)
      renderQueue.sync {
        gif.frames.append(frame)
      }
      renderSemaphore.signal()
    }
  }
  
  print("waiting on semaphore")
  renderSemaphore.wait()
  print("waiting on semaphore")
  renderSemaphore.wait()
  print("waiting on semaphore")
  renderSemaphore.wait()
  
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
//  var system = DriveSystem()
//  return system.rigidBodies
}
