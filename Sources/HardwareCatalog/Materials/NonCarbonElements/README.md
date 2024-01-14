# Non-Carbon Elements

This file documents the performance of MM4 when handling elements besides carbon and hydrogen. It reports partial charges, bond lengths, and bond angles of notable functional groups. The results are compared to xTB.

<!-- Method for creating images: take a ~1000x1000 screenshot of the 2000x2000 window. Downsample to ~500x500 and use 30-pt font. -->

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

### P-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a phosphorus.

|                             | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| --------------------------- | ------------- | ------------- | -------- | ------- |
| C charge (far from P)       | 0.000         | 0.000         | \-0.056  | \-0.049 |
| C charge (close to P)       | 0.105         | 0.105         | \-0.048  | \-0.057 |
| P charge                    | \-0.314       | \-0.314       | \-0.119  | 0.026   |
| C-C bond (far from P)       | 1.527         | 1.536         | 1.528    | 1.551   |
| C-C bond (close to P)       | 1.527         | 1.538         | 1.527    | 1.534   |
| C-P bond                    | 1.844         | 1.856         | 1.856    | 1.834   |
| C-H bond (close to P)       | 1.111         | 1.112         | 1.095    | 1.0926  |
| C-C-C angle (most strained) | 111.8         | 111.4         | 111.2    | 111.4   |
| C-C-P angle                 | 109.6         | 113.8         | 114.3    | 112.2   |
| C-P-C angle                 | 94.5          | 97.9          | 97.2     | 100.2   |
| P-C-H angle                 | 108.3         | 107.8         | 107.3    | 107.3   |

![P Doped Adamantane Bridgehead](./PDopedAdamantane_Bridgehead.jpg)

### Ge-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a germanium.

|                             | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| --------------------------- | ------------- | ------------- | -------- | ------- |
| C charge (far from Ge)      | 0.000         | 0.000         | \-0.048  | \-0.051 |
| C charge (close to Ge)      | \-0.068       | \-0.068       | \-0.100  | \-0.076 |
| Ge charge                   | 0.203         | 0.203         | 0.153    | 0.168   |
| H charge (on Ge)            | 0.000         | 0.000         | \-0.011  | \-0.035 |
| C-C bond (far from Ge)      | 1.527         | 1.545         | 1.530    | 1.560   |
| C-C bond (close to Ge)      | 1.527         | 1.544         | 1.531    | 1.541   |
| C-Ge bond                   | 1.949         | 1.945         | 1.971    | 1.947   |
| Ge-H bond                   | 1.555         | 1.554         | 1.521    | 1.557   |
| C-C-C angle (most strained) | 111.8         | 113.5         | 114.0    | 114.0   |
| C-C-Ge angle                | 109.3         | 105.8         | 105.7    | 104.5   |
| C-Ge-C angle                | 109.8         | 102.7         | 101.8    | 104.3   |
| Ge-C-H angle                | 111.9         | 111.6         | 112.4    | 109.4   |
| C-Ge-H angle                | 110.2         | 115.6         | 116.4    | 114.3   |

![Ge Doped Adamantane Bridgehead](./GeDopedAdamantane_Bridgehead.jpg)

### Silicon Carbide

Adamantane, with each bridgehead carbon replaced with a silicon.

### Carbon Phosphide

### Germanium Carbide

## Sidewall-Doped Adamantane

### Si-Doped Adamantane

Adamantane, with one sidewall carbon replaced with a silicon.

### S-Doped Adamantane

### Ge-Doped Adamantane

### Silicon Carbide

### Carbon Sulfide

### Germanium Carbide
