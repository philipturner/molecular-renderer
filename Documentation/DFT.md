# Density Functional Theory

Goal: Iron out a set of algorithms using Swift, Apple Accelerate, and the AMX coprocessor. Once they're tested, port necessary modules to C++, rocSOLVER, and HIP. Test Kahan block-summation algorithms that translate well between multiple vendors. Potentially prototype some in [metal-flash-attention](https://github.com/philipturner/metal-flash-attention), as the RDNA 3 matrix multiplication instruction has similar constraints to the Apple `simdgroup_matrix`. However, MFA has a battle-tested debugging suite for novel matmul algorithms.  Do not attempt to create matrix factorization kernels for the Apple GPU. Once the implementation is mature enough, rewrite the code from scratch and host it in [philipturner/density-functional-theory](https://github.com/philipturner/density-functional-theory).

Outcome: This approach should make the first proof-of-concept easier, using hardware I know very well to demonstrate mixed-precision optimizations. Brings ability to design reaction sequences and pair them with million-atom materializations of assembler ideas. This will eventually become part of comprehensive matter compilers (_Nanosystems 14.6.5_). Use this knowledge/experience to guide design of more manufacturable parts, and better CAD software for systems-level design.

## Technical Details

Goal: Combine a few recent advances in quantum chemistry. Do this with maximum possible CPU utilization and the simplest possible algorithms.
- [Effectively universal XC functional](https://www.science.org/doi/10.1126/science.abj6511) (2021)
  - More accurate than the B3LYP functional used for mechanosynthesis research, or at least not significantly worse.
  - The XC functional is often 90% of the maintenance and complexity of a DFT codebase. DeepMind's neural network makes the XC code ridiculously simple.
- [Dynamic precision for eigensolvers](https://pubs.acs.org/doi/10.1021/acs.jctc.2c00983) (2023)
  - Allows DFT to run on consumer hardware with limited FP64 units.
  - Use a similar solver described there, except replacing LOBPCG with LOBPCG II. This reduces bottlenecks from eigendecomposition (`eigh`) by 27x.
- [Real-space meshing techniques](https://arxiv.org/abs/cond-mat/0006239) (2023)
  - Real-space removes orbital basis sets, drastically simplifying the conceptual complexity.
  - Real-space removes the need for FFTs, both an additional library dependency and a bottleneck.
  - So far, every major commercial-quality codebase (GAUSSIAN, GAMESS) uses the plane-wave method. This CPU-designed algorithm isn't accelerator friendly, especially for medium-sized problems.

## Roadmap

This would start in 2024 at the earliest. The priority is getting supermassive systems on the molecular mechanics side, using the same superclusters described in this proposal.

## Recent Development 1

<s>I found a pathway that makes the proposed ideas much more feasible. I can modify the [DFT-FE](https://github.com/dftfeDevelopers/dftfe) codebase, adding Metal GPU support and the DeepMind 2021 XC functional. The plan is to analyze this codebase over the first few months of 2024, similarly to the actions taken with OpenMM in early 2023.

Progress on the Metal port is recorded here: https://gist.github.com/philipturner/4caf54432ef67d486bb55746e82f26a6</s>

False alarm: this just adds an immense $O(n^2)$ prefactor to delay $O(n^3)$ scaling for supermassive systems. Optimized for supercomputers, but much slower for personal computers.

## Recent Development 2

The DFT simulator may be unnecessary, as the silicon mechanosynthesis approach seems more viable than diamond mechanosynthesis. Silicon mechanosynthesis has already been proven in experiment and the build sequences are very simple. Therefore, there is less need to rely on quantum chemistry to predict which reactions will work.
