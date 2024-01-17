# Elastic Moduli

## Scene Setup

Experiment: a traditional energy minimizer does not minimize vdW potential energy to sufficient accuracy, only internal deformations. One typically starts a simulation with energy-minimized rigid bodies, then uses MD or RBD to simulate evolution over time.

Simulation: jig + specimen, 16,296 atoms, 9.6 ps evolution

Energy Minimization: 0.6 seconds latency

Molecular Dynamics: 2 fs timestep, 7.7 seconds latency

![MD Scene Setup](./ElasticModuli_MD_SceneSetup.jpg)

Rigid Body Dynamics: 40 fs timestep, 0.9 seconds latency

![RBD Scene Setup](./ElasticModuli_RBD_SceneSetup.jpg)

RBD seems sufficient for setting up the scene, and minimizing the vdW potential energy. One can erase the rigid body's velocity periodically to remove energy from the system. It is necessary to let the potential energy escape via kinetic energy. This differs from traditional energy minimization, which analyzes potential energy in isolation.

## Diamond Anvil

To prototype the act of measuring moduli, a virtual diamond anvil was created. The jig was anchored in place by setting the mass of every quaternary (`MM4AtomCode.quaternary`) atom to zero. An external force (`MM4ForceField.externalForces`) was exerted on a fraction of the specimen atoms. These atoms were located on the surface of outward-pointing faces. The normal force from the jig pointed opposite to the external forces, making the net force zero.

Pressure was calculated as the total force on any face, divided by the area of a 10x10 array of lattice cells. This significantly underestimates the pressure at extremely high pressures. The diamond can be compressed a factor of ~1.3x in each linear dimension, changing the area by ~1.7x.

The system was simulated for 120 frames. Each frames, the pressure per surface atom was incremented by 100 pN. The forcefield was minimized for a maximum of 30 iterations. The cap on iterations was set because minimizations started taking several seconds each with extreme pressures. The atom positions from each frame were recycled for the subsequent one, accelerating the convergence of the subsequent minimization.

The setup was retried with 20 femtoseconds of temporal evolution each frame. The results were not satisfactory. To get the same results, 100 femtoseconds of temporal evolution was required. However, the overall latency of MD simulation was half that of minimization. This could be explained by the GPU to CPU latency bottleneck. 100 femtoseconds is 50 timesteps, close to the 30 iterations for minimization. However, the system size is small enough that each singlepoint executes in under 1 millisecond.

```
Minimization:
frame=0, force=0 pN/atom, pressure=0 MPa
frame=10, force=1000 pN/atom, pressure=14226 MPa
frame=20, force=2000 pN/atom, pressure=28451 MPa
frame=30, force=3000 pN/atom, pressure=42677 MPa
frame=40, force=4000 pN/atom, pressure=56903 MPa
frame=50, force=5000 pN/atom, pressure=71128 MPa
frame=60, force=6000 pN/atom, pressure=85354 MPa
frame=70, force=7000 pN/atom, pressure=99580 MPa
frame=80, force=8000 pN/atom, pressure=113805 MPa
frame=90, force=9000 pN/atom, pressure=128031 MPa
frame=100, force=10000 pN/atom, pressure=142257 MPa
frame=110, force=11000 pN/atom, pressure=156482 MPa
Failed after 115 frames.
atoms: 16653
frames: 348
setup time: 22055.9 ms

Simulation:
frame=0, force=0 pN/atom, pressure=0 MPa
frame=10, force=1000 pN/atom, pressure=14226 MPa
frame=20, force=2000 pN/atom, pressure=28451 MPa
frame=30, force=3000 pN/atom, pressure=42677 MPa
frame=40, force=4000 pN/atom, pressure=56903 MPa
frame=50, force=5000 pN/atom, pressure=71128 MPa
frame=60, force=6000 pN/atom, pressure=85354 MPa
frame=70, force=7000 pN/atom, pressure=99580 MPa
frame=80, force=8000 pN/atom, pressure=113805 MPa
frame=90, force=9000 pN/atom, pressure=128031 MPa
frame=100, force=10000 pN/atom, pressure=142257 MPa
frame=110, force=11000 pN/atom, pressure=156482 MPa
Failed after 113 frames.
atoms: 16653
frames: 342
setup time: 11276.4 ms
```
