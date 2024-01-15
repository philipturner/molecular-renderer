# Non-Carbon Elements

This file validates the accuracy of MM4 when handling elements besides carbon and hydrogen. It reports partial charges, bond lengths, and bond angles of notable functional groups. The results are compared to xTB.

Cross-terms containing torsions are deactivated. It is unclear to what degree they're required for first-row electronegative elements. Therefore, this analysis has avoided N/O/F so far.

<!-- Method for creating images: take a ~1000x1000 screenshot of the 2000x2000 window. Downsample to ~500x500 and use 30-pt font. -->

<!-- Save results of this investigation to the Internet Archive. -->

Table of Contents
- [Bridgehead-Doped Adamantane](#bridgehead-doped-adamantane)
- [Sidewall-Doped Adamantane](#sidewall-doped-adamantane)
- [Elemental Silicon](#elemental-silicon)
- [Material Properties](#material-properties)

## Bridgehead-Doped Adamantane

### Si-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a silicon.

![Si Doped Adamantane Bridgehead](./SiDopedAdamantane_Bridgehead.jpg)

|                             | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| --------------------------- | ------------- | ------------- | -------- | ------- |
| C charge (far from Si)      | 0.000         | 0.000         | \-0.063  | \-0.050 |
| C charge (close to Si)      | \-0.078       | \-0.078       | \-0.158  | \-0.066 |
| Si charge                   | 0.233         | 0.233         | 0.491    | 0.081   |
| H charge (on Si)            | 0.000         | 0.000         | \-0.098  | \-0.014 |
| C-C bond (far from Si)      | 1.531         | 1.547         | 1.530    | 1.558   |
| C-C bond (close to Si)      | 1.536         | 1.550         | 1.531    | 1.540   |
| C-Si bond                   | 1.876         | 1.870         | 1.896    | 1.875   |
| Si-H bond                   | 1.483         | 1.482         | 1.466    | 1.480   |
| C-C-C angle (most strained) | 111.8         | 113.1         | 113.3    | 112.8   |
| C-C-Si angle                | 111.5         | 106.8         | 106.9    | 106.9   |
| C-Si-C angle                | 110.4         | 104.0         | 102.6    | 103.9   |
| Si-C-H angle                | 110.0         | 110.4         | 112.2    | 108.8   |
| C-Si-H angle                | 109.3         | 114.5         | 115.7    | 114.6   |

### Silicon Carbide

Adamantane, with each bridgehead carbon replaced with a silicon.

![Silicon Carbide Bridgehead](./SiliconCarbide_Bridgehead.jpg)

|                  | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| ---------------- | ------------- | ------------- | -------- | ------- |
| H charge (on C)  | 0.000         | 0.000         | 0.011    | 0.022   |
| H charge (on Si) | 0.000         | 0.000         | \-0.107  | \-0.069 |
| C charge         | \-0.155       | \-0.155       | \-0.271  | \-0.091 |
| Si charge        | 0.233         | 0.233         | 0.480    | 0.311   |
| C-Si bond        | 1.879         | 1.880         | 1.903    | 1.872   |
| C-H bond         | 1.112         | 1.112         | 1.088    | 1.088   |
| Si-H bond        | 1.487         | 1.487         | 1.482    | 1.451   |
| Si-C-Si angle    | 117.0         | 111.8         | 111.9    | 108.6   |
| C-Si-C angle     | 110.4         | 108.3         | 108.2    | 109.8   |
| H-C-Si angle     | 110.0         | 109.5         | 109.6    | 110.0   |
| H-Si-C angle     | 109.3         | 110.6         | 110.7    | 109.0   |
| H-C-H angle      | 107.7         | 107.1         | 106.2    | 108.8   |

### P-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a phosphorus.

![P Doped Adamantane Bridgehead](./PDopedAdamantane_Bridgehead.jpg)

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

### Carbon Phosphide

Adamantane, with each bridgehead carbon replaced with a phosphorus.

![Carbon Phosphide Bridgehead](./CarbonPhosphide_Bridgehead.jpg)

|             | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| ----------- | ------------- | ------------- | -------- | ------- |
| H charge    | 0.000         | 0.000         | 0.058    | 0.026   |
| C charge    | 0.209         | 0.209         | \-0.031  | \-0.068 |
| P charge    | \-0.313       | \-0.313       | \-0.127  | 0.026   |
| C-P bond    | 1.846         | 1.842         | 1.853    | 1.828   |
| C-H bond    | 1.110         | 1.110         | 1.098    | 1.088   |
| P-C-P angle | 109.5         | 125.0         | 124.0    | 120.7   |
| C-P-C angle | 94.5          | 100.7         | 101.3    | 103.4   |
| H-C-P angle | 108.3         | 106.2         | 106.3    | 107.1   |
| H-C-H angle | 107.7         | 105.7         | 106.6    | 107.2   |

### Ge-Doped Adamantane

Adamantane, with one bridgehead carbon replaced with a germanium.

![Ge Doped Adamantane Bridgehead](./GeDopedAdamantane_Bridgehead.jpg)

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

### Germanium Carbide

Adamantane, with each bridgehead carbon replaced with a germanium.

![Germanium Carbide Bridgehead](./GermaniumCarbide_Bridgehead.jpg)

|                  | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| ---------------- | ------------- | ------------- | -------- | ------- |
| H charge (on C)  | 0.000         | 0.000         | 0.043    | 0.016   |
| H charge (on Ge) | 0.000         | 0.000         | \-0.058  | \-0.034 |
| C charge         | \-0.136       | \-0.136       | \-0.157  | \-0.106 |
| Ge charge        | 0.203         | 0.203         | 0.165    | 0.146   |
| C-Ge bond        | 1.949         | 1.951         | 1.975    | 1.967   |
| C-H bond         | 1.112         | 1.112         | 1.090    | 1.087   |
| Ge-H bond        | 1.552         | 1.552         | 1.535    | 1.538   |
| Ge-C-Ge angle    | 112.0         | 109.8         | 109.8    | 109.1   |
| C-Ge-C angle     | 109.8         | 109.3         | 109.3    | 109.7   |
| H-C-Ge angle     | 111.9         | 110.2         | 109.8    | 109.7   |
| H-Ge-C angle     | 110.2         | 109.6         | 109.6    | 109.3   |
| H-C-H angle      | 107.7         | 106.4         | 107.6    | 108.9   |

## Sidewall-Doped Adamantane

### Si-Doped Adamantane

Adamantane, with one sidewall carbon replaced with a silicon.

![Si Doped Adamantane Sidewall](./SiDopedAdamantane_Sidewall.jpg)

|                                 | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| ------------------------------- | ------------- | ------------- | -------- | ------- |
| C charge (once removed from Si) | 0.000         | 0.000         | \-0.058  | \-0.211 |
| C charge (close to Si)          | \-0.078       | \-0.078       | \-0.114  | 0.427   |
| Si charge                       | 0.155         | 0.155         | 0.476    | \-0.208 |
| H charge (on Si)                | 0.000         | 0.000         | \-0.092  | 0.007   |
| C-C bond (once removed from Si) | 1.531         | 1.549         | 1.530    | 1.641   |
| C-C bond (close to Si)          | 1.536         | 1.551         | 1.530    | 1.624   |
| C-Si bond                       | 1.876         | 1.872         | 1.897    | 1.908   |
| Si-H bond                       | 1.483         | 1.483         | 1.467    | 1.434   |
| C-C-C angle (closest to Si)     | 111.8         | 112.2         | 112.0    | 114.9   |
| C-C-Si angle                    | 112.7         | 108.4         | 108.7    | 105.4   |
| C-Si-C angle                    | 109.2         | 97.6          | 95.6     | 105.0   |
| Si-C-H angle                    | 109.5         | 109.8         | 112.5    | 108.8   |
| C-Si-H angle                    | 107.0         | 111.9         | 112.5    | 110.8   |
| H-Si-H angle                    | 106.5         | 110.9         | 110.7    | 108.7   |

### Silicon Carbide

Adamantane, with each sidewall carbon replaced with a silicon.

![Silicon Carbide Sidewall](./SiliconCarbide_Sidewall.jpg)

|                  | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| ---------------- | ------------- | ------------- | -------- | ------- |
| H charge (on C)  | 0.000         | 0.000         | \-0.006  | \-0.133 |
| H charge (on Si) | 0.000         | 0.000         | \-0.123  | 0.009   |
| C charge         | \-0.233       | \-0.233       | \-0.344  | 0.416   |
| Si charge        | 0.155         | 0.155         | 0.480    | \-0.206 |
| C-Si bond        | 1.877         | 1.881         | 1.901    | 1.902   |
| C-H bond         | 1.112         | 1.112         | 1.090    | 1.133   |
| Si-H bond        | 1.488         | 1.488         | 1.476    | 1.437   |
| Si-C-Si angle    | 119.5         | 111.0         | 110.7    | 108.5   |
| C-Si-C angle     | 109.2         | 106.3         | 107.0    | 111.4   |
| H-C-Si angle     | 109.5         | 107.9         | 108.2    | 110.4   |
| H-Si-C angle     | 107.0         | 110.5         | 110.7    | 109.4   |
| H-Si-H angle     | 106.5         | 108.8         | 110.7    | 107.9   |

### S-Doped Adamantane

Adamantane, with one sidewall carbon replaced with a sulfur.

![S Doped Adamantane Sidewall](./SDopedAdamantane_Sidewall.jpg)

|                                | MM4Parameters | MM4ForceField | GFN2-xTB | GFN-FF  |
| ------------------------------ | ------------- | ------------- | -------- | ------- |
| C charge (once removed from S) | 0.000         | 0.000         | \-0.056  | \-0.047 |
| C charge (close to S)          | 0.080         | 0.080         | 0.040    | \-0.010 |
| S charge                       | \-0.161       | \-0.161       | \-0.229  | \-0.120 |
| C-C bond (once removed from S) | 1.527         | 1.538         | 1.530    | 1.551   |
| C-C bond (close to S)          | 1.526         | 1.539         | 1.523    | 1.544   |
| C-S bond                       | 1.814         | 1.828         | 1.826    | 1.799   |
| C-H bond (close to S)          | 1.097         | 1.099         | 1.093    | 1.101   |
| C-C-C angle (closest to S)     | 111.8         | 111.9         | 110.9    | 110.9   |
| C-C-S angle                    | 105.7         | 107.6         | 109.6    | 110.2   |
| C-S-C angle                    | 97.2          | 98.5          | 95.0     | 96.6    |
| S-C-H angle                    | 108.9         | 109.0         | 104.8    | 106.2   |

### Carbon Sulfide

### Ge-Doped Adamantane

### Germanium Carbide

Investigate the results with different Ge-C-Ge angles: ~109.5°, ~114.5°, ~119.5°.

## Elemental Silicon

Investigate the quaternary silicon atom. Is the MM3 parameter for Si-Si-Si bond angle correct? Does it hold true in pure elemental form, or only when bonded to carbon?

### Silyl-Adamantasilane

### Methyl-Adamantasilane

### C-Doped Silyl-Adamantasilane

### C-Doped Methyl-Adamantasilane

## Material Properties

Bulk material properties reflect accuracy of parameters for quaternary atoms. Adamantanes only represent surfaces (bridgehead and sidewall atoms).

TODO:
- Measure density and lattice constant
- Measure elastic/shear/flexural modulus
- Compare to results from xTB, where computationally feasible
- Compare to empirical data

Materials:
- Diamond
- Moissanite
- Germanium Carbide
- Silicon
- All crystals are cubic, with reconstructed (100) surfaces.
