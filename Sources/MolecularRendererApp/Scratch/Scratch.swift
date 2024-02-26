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
  
  let ΔtStart: Double = 0.040
  let αStart: Double = 0.25
  var Δt: Double = ΔtStart
  var α: Double = αStart
  var NP0: Int = 0
  
  var frames: [[Entity]] = []
  frames.append(createFrame(rigidBodies: rigidBodies))
  for frameID in 0..<500 {
    // Record which frame this is.
    forceField.positions = rigidBodies.flatMap(\.positions)
    print("frame: \(frameID)")
    
    // Assign forces.
    let forces = forceField.forces
    var cursor = 0
    for rigidBodyID in rigidBodies.indices {
      let spacing = rigidBodies[rigidBodyID].parameters.atoms.count
      let range = cursor..<(cursor + spacing)
      cursor += spacing
      rigidBodies[rigidBodyID].forces = Array(forces[range])
    }
    
    // Calculate P <- F * v.
    var P: Double = .zero
    for rigidBody in rigidBodies {
      let v = rigidBody.linearMomentum / rigidBody.mass
      let w = rigidBody.angularMomentum / rigidBody.momentOfInertia
      P += (rigidBody.netForce! * v).sum()
      P += (rigidBody.netTorque! * w).sum()
    }
    
    // Branch on the value of P.
    if P < 0 {
      print("restart")
      for rigidBodyID in rigidBodies.indices {
        rigidBodies[rigidBodyID].linearMomentum = .zero
        rigidBodies[rigidBodyID].angularMomentum = .zero
      }
      
      NP0 = 0
      Δt = max(Δt * 0.5, ΔtStart * 0.02)
      α = αStart
    } else {
      NP0 += 1
      if NP0 > 20 {
        Δt = min(Δt * 1.1, ΔtStart * 10)
        α *= 0.99
      }
      print("Δt:", Δt, "α:", α)
    }
    
    // Perform MD integration.
    for rigidBodyID in rigidBodies.indices {
      var copy = rigidBodies[rigidBodyID]
      defer {
        rigidBodies[rigidBodyID] = copy
      }
      
      var v = copy.linearMomentum / copy.mass
      var w = copy.angularMomentum / copy.momentOfInertia
      let f = copy.netForce!
      let τ = copy.netTorque!
      
      let vNorm = (v * v).sum().squareRoot()
      let fNorm = (f * f).sum().squareRoot()
      var forceScale = vNorm / fNorm
      if forceScale.isNaN || forceScale.isInfinite {
        forceScale = .zero
      }
      
      let wNorm = (w * w).sum().squareRoot()
      let τNorm = (τ * τ).sum().squareRoot()
      var torqueScale = wNorm / τNorm
      if torqueScale.isNaN || torqueScale.isInfinite {
        torqueScale = .zero
      }
      
      // Semi-Implicit Euler Integration
      v += Δt * copy.netForce! / copy.mass
      w += Δt * copy.netTorque! / copy.momentOfInertia
      v = (1 - α) * v + α * f * forceScale
      w = (1 - α) * w + α * τ * torqueScale
      
      // Regular MD integration.
      copy.linearMomentum = v * copy.mass
      copy.angularMomentum = w * copy.momentOfInertia
      if rigidBodyID == 0 || rigidBodyID == 5 {
        copy.linearMomentum = .zero
        copy.angularMomentum = .zero
      }
      let linearVelocity = copy.linearMomentum / copy.mass
      let angularVelocity = copy.angularMomentum / copy.momentOfInertia
      let angularSpeed = (angularVelocity * angularVelocity).sum().squareRoot()
      copy.centerOfMass += Δt * linearVelocity
      copy.rotate(angle: Δt * angularSpeed)
    }
    
    // Display the current positions.
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
