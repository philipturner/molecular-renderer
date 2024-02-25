// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[Entity]] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  // - Take at least one screenshot to document this experiment.
  
  var system = System()
  system.minimize()
  system.initializeRigidBodies()
  
  // Set up the system for simulation.
  for rodID in system.rods.indices {
    system.rods[rodID].rigidBody!.centerOfMass += SIMD3(0, 0, -0.5)
  }
  
  // Start with a short rigid body dynamics simulation, with the housing and
  // drive wall positionally constrained. Test whether the rods fall into their
  // lowest-energy state.
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(system.housing.rigidBody!)
  for rod in system.rods {
    rigidBodies.append(rod.rigidBody!)
  }
  rigidBodies.append(system.driveWall.rigidBody!)
  
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  for rigidBody in rigidBodies {
    systemParameters.append(contentsOf: rigidBody.parameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = systemParameters
  forceFieldDesc.cutoffDistance = 2
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  func createFrame(rigidBodies: [MM4RigidBody]) -> [Entity] {
    var output: [Entity] = []
    for rigidBody in rigidBodies {
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        let entity = Entity(storage: storage)
        output.append(entity)
      }
    }
    return output
  }
  
  let step: Float = 0.001
  let tolforce: Float = 1 // 1 pN
  
  var alphaStart: Float = 0.1
  var dt: Float = step
  var alpha: Float = alphaStart
  var pTimes: Int = 0
  var fAlpha: Float = 0.99
  var nMin: Int = 5
  var fInc: Float = 1.1
  var dtMax: Float = 10 * dt
  var fDec: Float = 0.5
  
  var oldXX = rigidBodies
  var oldPValue: Float = 0
  var pValue: Float = 0
  
  var frames: [[Entity]] = []
  frames.append(createFrame(rigidBodies: rigidBodies))
  for frameID in 0..<600 {
    forceField.positions = rigidBodies.flatMap(\.positions)
    print("frame: \(frameID)")
    
    /*
     auto force = func(xx);
     old_p_value = p_value;
     */
    let forces = forceField.forces
    oldPValue = pValue
    var linearForces: [SIMD3<Double>] = []
    var linearVelocities: [SIMD3<Double>] = []
    // NOTE: Leaving angular velocities out of the integrator. It requires
    // extra effort to track rotations from the previous timestep and
    // interpolate those rotations.
    
    var cursor = 0
    for rigidBodyID in rigidBodies.indices {
      let spacing = rigidBodies[rigidBodyID].parameters.atoms.count
      let range = cursor..<(cursor + spacing)
      cursor += spacing
      
      var copy = rigidBodies[rigidBodyID]
      copy.forces = Array(forces[range])
      
      /*
       p_value = operations::sum(force, vel, [](auto fo, auto ve) { return dot(fo, ve);});
       */
      var linearForce = copy.netForce!
      var linearVelocity = copy.linearMomentum / copy.mass
      pValue += Float((linearForce * linearVelocity).sum())
      
      
      
      /*
       auto norm_vel = operations::sum(vel, [](auto xx) { return norm(xx); });
       auto norm_force = operations::sum(force, [](auto xx) { return norm(xx); });
       */
      let normLinearForce = (linearForce * linearForce)
        .sum().squareRoot()
      let normLinearVelocity = (linearVelocity * linearVelocity)
        .sum().squareRoot()
      
      /*
       for(auto ii = 0; ii < vel.size(); ii++) vel[ii] = (1.0 - alpha)*vel[ii] + alpha*force[ii]*sqrt(norm_vel/norm_force);
       */
      let linearForceAligned = linearForce * (
        normLinearVelocity / normLinearForce).squareRoot()
      linearVelocity = Double(1 - alpha) * linearVelocity
      + Double(alpha) * linearForceAligned
      
      linearForces.append(linearForce)
      linearVelocities.append(linearVelocity)
    }
    
    /*
     if(p_times == 0 or p_value > 0.0) {
       if(p_times > n_min) {
         dt = std::min(dt*f_inc, dt_max);
         alpha *= f_alpha;
       }

       p_times++;
     } else {
     */
    if pTimes == 0 || pValue > 0 {
      if pTimes > nMin {
        dt = min(dt * fInc, dtMax)
        alpha *= fAlpha
      }
      pTimes += 1
    } else {
      /*
       p_times = 0;
       dt *= f_dec;
       alpha = alpha_start;

       auto den = old_p_value - p_value;
       auto c0 = -p_value/den;
       auto c1 = old_p_value/den;

       if(fabs(den) < 1e-16) c0 = c1 = 0.5;
       */
      pTimes = 0
      dt *= fDec
      alpha = alphaStart
      
      #if false
      let den = oldPValue - pValue
      var c0 = -pValue / den
      var c1 = oldPValue / den
      
      if den.magnitude < 1e-16 {
        c0 = 0.5
        c1 = 0.5
      }
      
      /*
       for(auto ii = 0; ii < vel.size(); ii++) {
         xx[ii] = c0*old_xx[ii] + c1*xx[ii];
         vel[ii] = vector3{0.0, 0.0, 0.0};
       }
       
       continue;
       */
      for rigidBodyID in rigidBodies.indices {
        if rigidBodyID == 0 && rigidBodyID == 5 {
          continue
        }
        
        let value1 = oldXX[rigidBodyID].centerOfMass
        let value2 = rigidBodies[rigidBodyID].centerOfMass
        rigidBodies[rigidBodyID].centerOfMass = Double(c0) * oldXX[rigidBodyID].centerOfMass + Double(c1) * rigidBodies[rigidBodyID].centerOfMass
        rigidBodies[rigidBodyID].linearMomentum = .zero
        
        let value3 = rigidBodies[rigidBodyID].centerOfMass
//        print("combined: \(value1), \(value2) -> \(value3)")
      }
      #endif
      
      rigidBodies = oldXX
      for i in rigidBodies.indices {
        rigidBodies[i].linearMomentum = .zero
        oldXX[i].linearMomentum = .zero
      }
      
      frames.append(createFrame(rigidBodies: rigidBodies))
      #if false
      print("c0:", c0)
      print("c1:", c1)
      #endif
      print("continue")
      continue
    }
    
    /*
     auto max_force = 0.0;
     for(auto ii = 0; ii < force.size(); ii++) max_force = std::max(max_force, fabs(force[ii]));
     if(max_force < tolforce) break;
     */
    var maxForce: Float = .zero
    for linearForce in linearForces {
      let normLinearForce = (linearForce * linearForce)
        .sum().squareRoot()
      maxForce = max(maxForce, Float(normLinearForce))
    }
    print("max force: \(maxForce)")
    if maxForce < tolforce {
      print("break")
      break
    }
    
    /*
     for(auto ii = 0; ii < vel.size(); ii++) {
       vel[ii] += force[ii]*dt/mass;
       old_xx[ii] = xx[ii];
       xx[ii]  += vel[ii]*dt;
     }
     */
    for rigidBodyID in rigidBodies.indices {
      var linearVelocity = linearVelocities[rigidBodyID]
      let linearForce = linearForces[rigidBodyID]
      let mass = rigidBodies[rigidBodyID].mass
      linearVelocity += linearForce * Double(dt) / mass
      rigidBodies[rigidBodyID].linearMomentum = linearVelocity * mass
      
      oldXX[rigidBodyID] = rigidBodies[rigidBodyID]
      rigidBodies[rigidBodyID].centerOfMass += linearVelocity * Double(dt)
    }
    
    frames.append(createFrame(rigidBodies: rigidBodies))
  }
  
  // Demonstrate rigid body energy minimization with FIRE. This is a proof of
  // concept for the DFT simulator. Use INQ as a reference, then incorporate the
  // improvements from FIRE 2.0 and ABC.
  
  /*
     auto alpha_start = 0.1;
     auto dt = step;
     auto alpha = alpha_start;
     auto p_times = 0;
     auto f_alpha = 0.99;
     auto n_min = 5;
     auto f_inc = 1.1;
     auto dt_max = 10.0*dt;
     auto f_dec = 0.5;
     auto const mass = 1.0;
     auto const maxiter = 200;

     auto old_xx = xx;
     auto old_p_value = 0.0;
     auto p_value = 0.0;
     
     auto vel = ArrayType(xx.size(), {0.0, 0.0, 0.0});
     for(int iiter = 0; iiter < maxiter; iiter++){

       auto force = func(xx);
       old_p_value = p_value;
       p_value = operations::sum(force, vel, [](auto fo, auto ve) { return dot(fo, ve);});

       auto norm_vel = operations::sum(vel, [](auto xx) { return norm(xx); });
       auto norm_force = operations::sum(force, [](auto xx) { return norm(xx); });
       for(auto ii = 0; ii < vel.size(); ii++) vel[ii] = (1.0 - alpha)*vel[ii] + alpha*force[ii]*sqrt(norm_vel/norm_force);
         
       if(p_times == 0 or p_value > 0.0) {
         if(p_times > n_min) {
           dt = std::min(dt*f_inc, dt_max);
           alpha *= f_alpha;
         }

         p_times++;
       } else {
         
         p_times = 0;
         dt *= f_dec;
         alpha = alpha_start;

         auto den = old_p_value - p_value;
         auto c0 = -p_value/den;
         auto c1 = old_p_value/den;

         if(fabs(den) < 1e-16) c0 = c1 = 0.5;
         
         for(auto ii = 0; ii < vel.size(); ii++) {
           xx[ii] = c0*old_xx[ii] + c1*xx[ii];
           vel[ii] = vector3{0.0, 0.0, 0.0};
         }
         
         continue;

       }

       auto max_force = 0.0;
       for(auto ii = 0; ii < force.size(); ii++) max_force = std::max(max_force, fabs(force[ii]));
       if(max_force < tolforce) break;
       
       for(auto ii = 0; ii < vel.size(); ii++) {
         vel[ii] += force[ii]*dt/mass;
         old_xx[ii] = xx[ii];
         xx[ii]  += vel[ii]*dt;
       }
       
     }

   */
  
  return frames
}
