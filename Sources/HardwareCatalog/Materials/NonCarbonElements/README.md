# Non-Carbon Elements

This file documents the performance of MM4 when handling elements besides carbon and hydrogen. It reports partial charges, bond lengths, and bond angles of notable functional groups. The results are compared to xTB.

## Bridgehead-Doped Adamantane

### Si-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a silicon.

|                             | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| --------------------------- | ------------- | ------------- | -------- | ------- |
| C charge (far from Si)      | 0.000         | 0.000         | \-0.063  | \-0.039 |
| C charge (close to Si)      | \-0.078       | \-0.078       | \-0.158  | \-0.055 |
| Si charge                   | 0.233         | 0.233         | 0.491    | 0.063   |
| H charge (on Si)            | 0.000         | 0.000         | \-0.098  | \-0.008 |
| C-C bond (far from Si)      | 1.531         | 1.547         | 1.530    | 1.558   |
| C-C bond (close to Si)      | 1.536         | 1.550         | 1.531    | 1.540   |
| C-Si bond                   | 1.876         | 1.870         | 1.896    | 1.875   |
| Si-H bond                   | 1.483         | 1.482         | 1.466    | 1.480   |
| C-C-C angle (most strained) | 111.8         | 113.1         | 113.3    | 112.8   |
| C-C-Si angle                | 111.5         | 106.8         | 106.9    | 106.9   |
| C-Si-C angle                | 110.4         | 103.9         | 102.6    | 103.9   |
| Si-C-H angle                | 110.0         | 110.4         | 112.2    | 108.8   |
| C-Si-H angle                | 109.3         | 114.6         | 115.7    | 114.6   |

![Si Doped Adamantane Bridgehead](./SiDopedAdamantane_Bridgehead.jpg)

### Ge-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a germanium.

### N-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a nitrogen.

### Silicon Carbide

Adamantane, with each bridgehead carbon replaced with a silicon.

### Carbon Nitride

Adamantane, with each bridgehead carbon replaced with a nitrogen.

## Sidewall-Doped Adamantane

### Si-Doped Adamantane

Adamantane, with one sidewall carbon replaced with a silicon.

### Ge-Doped Adamantane

Adamantane, with one sidewall carbon replaced with a germanium.

### S-Doped Adamantane

Adamantane, with one sidewall carbon replaced with a sulfur.

### Germanium Carbide

Adamantane, with each sidewall carbon replaced with a germanium.

### Carbon Sulfide

Adamantane, with each sidewall carbon replaced with a sulfur.
