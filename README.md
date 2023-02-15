# Molecular Renderer

Scriptable Mac application for running OpenMM simulations and visualizing them at 120 Hz.

TODO:
- Are massive-LOD spheres or virtualized ray-traced geometry faster?
- Gather data at sub-frame resolution and incorporate motion blur (only for smaller simulations).
- Separate Swift files for ported forcefields (oxDNA, AIREBO, etc.), unless they need separate plugins.
- Modular mechanism to plug in different scripts, so I can save my research in a separate repo.
- Video exporting tool, demo video of a rod-logic mechanical computer.
- Limited interactivity with the visualization.
- Serialization format to save an in-progress simulation.
