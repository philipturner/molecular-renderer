# (Prototype) Hardware Description Language

This is a precursor to the eventual hardware description language that atomCAD will build. The purpose is to allow reasonably efficient workflows for designing crystolecules here and now.
- This will enable the creation of a mechanical parts catalog covering several different categories. Each part will have Markdown documentation (when possible) and Swift APIs for instantiating parts/machines in larger assemblies. Heavy emphasis on making the parts <b>parametric</b>, so they can be used with a different material or dimension than originally conceived.
- Tutorials and well-maintained documentation will be provided, to onboard new engineers and provide the skills for making crystolecules. This will cover common pitfalls in design, such as actions that expose triply-unbonded carbon atoms (which passivate to methyl groups).
- The API will be geared toward those with <b>little to no Swift experience</b>. It will make minimal use of Swift's many examples of syntactic sugar. When possible, subsets of the HDL or hardware catalog's functionality will be available through bindings to alternative programming languages.
- The codebase will only depend on <b>cross-platform</b> Swift packages, even if Apple-specific libraries have higher performance.

## How it Works

At the atomic scale, constructive solid geometry is much easier than at the macroscale; there is no need to implicitly store shapes as equations. Instead, add or remove atoms from a grid held in computer memory. As the number of atoms can grow quite large, and many transformations can be applied, this approach can be computationally heavy. To achieve low latency, the compiler for translating the HDL (or UI actions) into geometry must be optimized for speed.

