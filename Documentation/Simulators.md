# Simulators

| Level of Theory | Acceleration | Use Case |
| --------------- | ------- | -------- |
| MM4 | GPU | Nanomachine Parts, Nanomechanical Systems |
| GFN-FF\* | CPU | ~200 atoms, checking correctness of MM4 |
| GFN2-xTB\* | CPU | ~50 atoms, checking correctness of MM4 |

\*The CUDA-only acceleration for this library is quite poor, with 1/3 the utilization of CPU, even with supermassive systems (3000 atoms). The dominant use case will be 1/10 as many atoms with 1/100x to 1/1000x the compute cost. In addition, the Nvidia compiler is broken in xTB at the moment. This means no alternative vendors are at a disadvantage from a GPU acceleration that would work, but only if you bought Nvidia GPUs.
