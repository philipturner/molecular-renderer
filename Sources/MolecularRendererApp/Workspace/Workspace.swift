import CairoGraphics
import Foundation
import GIF
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// Film Storyboard
//
// Preparing Surface
// - H-passivated silicon wafer
// - molecular dynamics at 1200 C
// - hydrogens leave surface
// - molecular dynamics at 400 C
//   - set HMR to 1
//   - give ghost hydrogens the atomic mass of Cl
//   - set equilibrium bond length to Si-Cl length
// - form chlorinated Si(111) with chlorine gas
// - form partially hydrogenated, partially chlorinated Si(111) with atomic H
//   - 50% hydrogenation, randomly distributed
// - deposit tripods as vapor
//   - recycle leg design from HDL test suite
//   - energy-minimize the following variants in xTB
//     - C*
//     - C-Br
//     - Ge*
//     - Ge-CH**
//     - Ge-CHBr2
//     - Ge-CH2*
//     - Ge-CH2Br
//     - Sn*
//     - Sn-H
// - remove halogen caps with 254 nm light
//
// Mechanosynthesis
// - one AFM probe appears, with tip already sharpened
//   - silicon-(H3C)3-Si*
//   - use relaxed structure after energy minimization with MM4
// - probe scans the surface
// - select a site near center of surface, with three nearby Si-H groups
// - compile three times
//   - voltage pulse:               Si* + H-Si          surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - tooltip charging:            Si* + *CH2-Ge       tripod
//   - methylation:                 Si-CH2* + *Si       surface
//   - tooltip charging:            Si* + H-Sn          tripod
//   - hydrogen donation:           Si-H + *H2C-Si      surface
// - 6-membered ring forms
//   - voltage pulse:               Si* + H3C-Si        surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - voltage pulse:               Si* + H3C-Si        surface
//   - 5-membered ring forms:       Si-CH* + *HC-Si     surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - tooltip charging:            carbene feedstock   tripod
//   - carbene addition:            Si-CH** + HCCH      surface
// - adamantange cage forms
//   - tooltip charging:            Si* + H-Sn          tripod
//   - hydrogen donation:           Si-H + *HC-(CH2)2   surface
//   - voltage pulse                Si* + H3C-Si        surface
//   - use tripod as hydrogen dump: Si-H + *C           tripod
//   - voltage pulse                Si* + H2C-(CH2)2    surface
//   - adamantane cage forms:       Si-CH* + *HC-(CH2)2 surface
//
// System Construction
// - move camera to an empty silicon surface
// - synthesize diamond lattice: AFM follows atoms in Morton order
// - compile abbreviated mechanosynthesis animation for every part
// - lift parts into exploded view
// - energy-minimize from compiled to relaxed structure
//   - show each frame of the minimization, if practical
// - assemble parts on top of each other
// - rotate so the flywheel points toward viewer
//
// System Operation
// - animate the flywheel-piston system moving
// - parallel 8-bit half adder, due to restriction to 3 unique clock phases
// - will include MD simulation at 298 K
// - [storyboard in progress]
//
// Credits
// - Author
// - Music
// - Inspiration (for mechanosynthesis and rod logic)

func createRigidBodyFrames() -> [[MM4RigidBody]] {
  // Create the rigid bodies.
  let system = DriveSystem()
  var rigidBodies = system.rigidBodies
  for i in rigidBodies.indices {
    rigidBodies[i].centerOfMass += SIMD3(-15, -3, -40)
  }
//  return [rigidBodies]
  
  // Create the force field.
  var forceFieldParameters = rigidBodies[0].parameters
  for rigidBody in rigidBodies[1...] {
    let parameters = rigidBody.parameters
    forceFieldParameters.append(contentsOf: parameters)
  }
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = forceFieldParameters
  forceFieldDesc.cutoffDistance = 1
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  // Create the frames.
  var frames: [[MM4RigidBody]] = [rigidBodies]
  for frameID in 0..<2000 {
    print("simulation frame:", frameID)
    
    if frameID == 240 {
      var flywheel = rigidBodies[1]
      let angularVelocity: SIMD3<Double> = .init(-0.063, 0, 0)
      let momentOfIneertia = flywheel.momentOfInertia
      flywheel.angularMomentum = momentOfIneertia * angularVelocity
      rigidBodies[1] = flywheel
    }
    
    var positions = rigidBodies[0].positions
    for rigidBody in rigidBodies[1...] {
      positions.append(contentsOf: rigidBody.positions)
    }
    forceField.positions = positions
    let forces = forceField.forces
    
    // Assign the forces.
    var cursor = 0
    for rigidBodyID in rigidBodies.indices {
      let spacing = rigidBodies[rigidBodyID].parameters.atoms.count
      let range = cursor..<(cursor + spacing)
      cursor += spacing
      rigidBodies[rigidBodyID].forces = Array(forces[range])
    }
    
    // Perform time integration, damping the kinetic energy.
    for i in rigidBodies.indices {
      rigidBodies[i].linearMomentum += 0.040 * rigidBodies[i].netForce!
      rigidBodies[i].angularMomentum += 0.040 * rigidBodies[i].netTorque!
      
      // Dampen the kinetic energy, emulating thermal energy dissipation from
      // bonded forces.
      if frameID < 240 {
        if frameID % 60 == 0 {
          rigidBodies[i].linearMomentum = .zero
          rigidBodies[i].angularMomentum = .zero
        } else {
          rigidBodies[i].linearMomentum *= 0.98
          rigidBodies[i].angularMomentum *= 0.98
        }
      } else {
        if i == 0 || i == 3 {
          rigidBodies[i].linearMomentum *= 0.98
          rigidBodies[i].angularMomentum *= 0.98
        }
      }
      
      let v = rigidBodies[i].linearMomentum / rigidBodies[i].mass
      let w = rigidBodies[i].angularMomentum / rigidBodies[i].momentOfInertia
      let angularSpeed = (w * w).sum().squareRoot()
      rigidBodies[i].centerOfMass += 0.040 * v
      rigidBodies[i].rotate(angle: 0.040 * angularSpeed)
    }
    
    // Record the data for this frame.
    frames.append(rigidBodies)
  }
  
  // Return the frames.
  return frames
}

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

// MARK: - Renderer Scripting

func createGeometry() -> [[Entity]] {
  let rigidBodyFrames = createRigidBodyFrames()
  let atomFrames = createAtomFrames(rigidBodyFrames: rigidBodyFrames)
  return atomFrames
}

func renderOffline(renderingEngine: MRRenderer) {
  // Second task:
  // - Compile and minimize the tripod tooltips.
  //   - Anchor every atom in the SiH3 groups.
  //   - Get the xtb command-line binary running with Accelerate.
  // - Serialize the tripods as Swift source code.
  
  print()
  print("Hello, world!")
  
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
  
  let atomProvider = Provider()
  renderingEngine.setAtomProvider(atomProvider)
  renderingEngine.setQuality(
    MRQuality(minSamples: 7, maxSamples: 32, qualityCoefficient: 100))
  
  let rotation: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) = (
    SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
  renderingEngine.setCamera(
    MRCamera(position: .zero, rotation: rotation, fovDegrees: 60))
  renderingEngine.setLights([
    MRLight(origin: .zero, diffusePower: 1, specularPower: 1)
  ])
  
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
