//
//  MM4MorseParameters.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/11/23.
//

import Foundation

class MM4MorseParameters {
  static let global = MM4MorseParameters()
  
  init() {
    
  }
}

extension MM4MorseParameters {
  // It should be possible to parse this, as every atom name comes with the MM3
  // atom type. There are always 5 numbers after the names, representing the 5
  // parameters. Atoms new to MM4 (5-member ring carbons, etc.) will have to
  // interpolate, making an educated guess based on the CCSD value. For example,
  // it seems the alkane-cyclobutane bond in the MM3 forcefield was 123-56.
  static let sourceString = """
// Originated from: https://pubs.acs.org/doi/epdf/10.1021/acs.jpca.8b12006
// Copyright (c) 2019 American Chemical Society

atom type 1 (MM3 type number),atom type 2 (MM3 type number),k /mdyne Å−1 k /mdyne Å−1h,r /Å h,,D /mdyne Å e,,α,,αcalc/Å−1
C CSP3 alkane (1),C CSP3 alkane (1),4.490,1.525,,,1.130,,5.069,1.409
C CSP3 alkane (1),C CSP2 alkene (2),6.300,1.499,,,1.242,,5.529,1.593
C CSP3 alkane (1),C CSP2 carbonyl (3),4.800,1.509,,,0.994,,4.892,1.554
C CSP3 alkane (1),C CSP alkyne (4),5.500,1.470,,,0.995,,5.183,1.663
C CSP3 alkane (1),"H except on N, O, S (5)",4.740,1.112,,,0.854,,5.168,1.666
C CSP3 alkane (1),"O C−O−H, C−O−C, O−O (6)",5.700,1.413,,,0.851,,5.409,1.830
C CSP3 alkane (1),N NSP3 (8),5.300,1.448,,,1.140,,5.670,1.525
C CSP3 alkane (1),N NSP2 (9),5.210,1.446,,,0.968,,5.510,1.640
C CSP3 alkane (1),F fluoride (11),5.900,1.390,,,0.989,,6.227,1.727
C CSP3 alkane (1),Cl chloride (12),3.100,1.791,,,0.629,,6.043,1.569
C CSP3 alkane (1),Br bromide (13),2.300,1.944,,,0.708,,3.087,1.275
C CSP3 alkane (1),I iodide (14),2.150,2.166,,,0.635,,2.337,1.301
C CSP3 alkane (1),S  −S− sulfide (15),3.000,1.805,,,0.651,,3.325,1.518
C CSP3 alkane (1),S+ > S+ sulfonium (16),3.213,1.816,,,0.666,,3.254,1.554
C CSP3 alkane (1),S > SO sulfoxide (17),2.950,1.800,,,0.541,,3.160,1.651
C CSP3 alkane (1),S > SO2 sulfone (18),3.100,1.772,,,0.674,,3.435,1.516
C CSP3 alkane (1),Si silane (19),3.050,1.876,,,0.812,,3.040,1.370
C CSP3 alkane (1),C cyclopropane (22),5.000,1.511,,,0.919,,4.784,1.649
C CSP3 alkane (1),P > P-phosphine (25),2.940,1.843,,,0.702,,3.152,1.448
C CSP3 alkane (1),B > B-trigonal (26),4.501,1.577,,,0.862,,3.781,1.616
C CSP3 alkane (1),Ge germanium (31),2.720,1.949,,,0.744,,2.761,1.352
C CSP3 alkane (1),Sn tin (32),2.124,2.147,,,0.657,,2.139,1.272
C CSP3 alkane (1),Pb lead (IV) (33),1.900,2.242,,,0.553,,1.793,1.311
C CSP3 alkane (1),Se selenium (34),2.680,1.948,,,0.692,,2.823,1.391
C CSP3 alkane (1),Te tellurium (35),2.700,2.140,,,0.625,,2.445,1.469
C CSP3 alkane (1),N −NC−/PYR (delocalized) (37),5.000,1.434,,,0.756,,5.207,1.819
C CSP3 alkane (1),N+ NSP3 ammonium (39),4.274,1.511,,,0.810,,4.422,1.624
C CSP3 alkane (1),N NSP2 pyrrole (40),4.230,1.490,,,0.997,,5.472,1.456
C CSP3 alkane (1),O OSP2 furan (41),5.400,1.420,,,0.782,,5.411,1.858
C CSP3 alkane (1),N N−O azoxy (local) (43),5.200,1.483,,,0.532,,4.442,2.210
C CSP3 alkane (1),N nitro (46),5.500,1.495,,,0.629,,4.288,2.091
C CSP3 alkane (1),C benzene (localized) (50),6.300,1.499,,,0.951,,4.832,1.820
C CSP3 alkane (1),C CSP3 cyclobutane (56),4.490,1.525,,,0.881,,4.615,1.596
C CSP3 alkane (1),C CSP2 cyclobutene (57),6.300,1.499,,,0.924,,4.851,1.847
C CSP3 alkane (1),NN− imine (localized) (72),5.000,1.439,,,0.718,,5.035,1.866
C CSP3 alkane (1),"O O−H, O−C (carboxyl) (75)",5.700,1.413,,,0.860,,5.176,1.820
C CSP3 alkane (1),N −N azoxy (local) (109),4.480,1.453,,,0.711,,4.887,1.775
C CSP3 alkane (1),N+ −N(+) imminium (110),6.420,1.470,,,0.821,,4.627,1.978
C CSP3 alkane (1),O > N−OH hydroxyamine (145),5.850,1.368,,,0.751,,5.483,1.973
C CSP3 alkane (1),N > N−OH hydroxyamine (146),4.800,1.414,,,0.796,,5.201,1.736
C CSP3 alkane (1),N NSP3 hydrazine (150),3.800,1.443,,,0.773,,5.179,1.567
C CSP3 alkane (1),S > SO2 sulfonamide (154),3.104,1.776,,,0.743,,3.681,1.445
C CSP3 alkane (1),N NSP3 sulfonamide (155),4.454,1.454,,,0.885,,5.155,1.587
C CSP3 alkane (1),O O−PO phosphate (159),4.400,1.424,,,0.895,,5.224,1.568
C CSP2 alkene (2),C CSP2 alkene (2),7.500,1.332,,,1.602,,9.671,1.530
C CSP2 alkene (2),C CSP2 carbonyl (3),8.500,1.354,,,0.779,,4.868,2.336
C CSP2 alkene (2),C CSP alkyne (4),11.200,1.312,,,1.030,,6.061,2.332
C CSP2 alkene (2),"H except on N, O ,S (5)",5.150,1.101,,,0.912,,5.475,1.680
C CSP2 alkene (2),"O C−O−H, C−O−C, O−O (6)",6.000,1.354,,,0.912,,6.567,1.813
C CSP2 alkene (2),N NSP3 (8),6.320,1.369,,,1.039,,6.578,1.744
C CSP2 alkene (2),N NSP2 (9),5.960,1.410,,,1.054,,6.214,1.681
C CSP2 alkene (2),F fluoride (11),5.500,1.354,,,0.985,,6.384,1.671
C CSP2 alkene (2),Cl chloride (12),2.800,1.727,,,1.219,,3.443,1.071
C CSP2 alkene (2),Br bromide (13),2.500,1.890,,,0.727,,3.336,1.311
C CSP2 alkene (2),I iodide (14),2.480,2.075,,,0.681,,2.784,1.349
C CSP2 alkene (2),S > SO2 sulfone (18),2.800,1.772,,,0.662,,3.350,1.455
C CSP2 alkene (2),Si silane (19),3.000,1.854,,,0.836,,3.124,1.339
C CSP2 alkene (2),C cyclopropane (22),5.700,1.460,,,0.955,,5.146,1.728
C CSP2 alkene (2),P > P-phosphine (25),2.910,1.828,,,0.723,,3.230,1.419
C CSP2 alkene (2),B > B-trigonal (26),3.460,1.550,,,0.905,,4.054,1.383

atom type 1 (MM3 type number),atom type 2 (MM3 type number),k /mdyne Å−1 h,,r /Å h,,D /mdyne Å e,,k /mdyne Å−1 α,,αcalc/Å,−1
C CSP2 alkene (2),Ge germanium (31),,3.580,1.935,,,0.745,,2.822,1.550,
C CSP2 alkene (2),D deuterium (36),,5.150,1.096,,,0.912,,5.512,1.680,
C CSP2 alkene (2),N−NC−/PYR (delocalized) (37),,9.000,1.271,,,1.586,,10.187,1.685,
C CSP2 alkene (2),C CSP2 cyclopropene (38),,9.600,1.336,,,0.884,,5.572,2.330,
C CSP2 alkene (2),N+ NSP3 ammonium (39),,11.090,1.260,,,1.039,,8.383,2.310,
C CSP2 alkene (2),N NSP2 pyrrole (40),,11.090,1.266,,,1.791,,10.620,1.759,
C CSP2 alkene (2),O OSP2 furan (41),,12.200,1.218,,,1.041,,7.421,2.420,
C CSP2 alkene (2),S SSP2 thiophene (42),,7.171,1.537,,,1.408,,5.197,1.596,
C CSP2 alkene (2),N nitro (46),,5.050,1.473,,,0.653,,4.624,1.966,
C CSP2 alkene (2),C benzene (localized) (50),,5.280,1.434,,,0.996,,5.337,1.628,
C CSP2 alkene (2),C CSP2 cyclobutene (57),,7.500,1.333,,,0.925,,5.579,2.013,
C CSP2 alkene (2),NN− imine (localized) (72),,9.000,1.270,,,1.281,,11.272,1.875,
C CSP2 alkene (2),CCO ketene (106),,11.900,1.311,,,1.127,,8.914,2.298,
C CSP2 alkene (2),NN−OH oxime (108),,8.702,1.284,,,1.086,,11.358,2.001,
C CSP2 alkene (2),N+ −N(+) pyridinium (111),,8.300,1.274,,,1.521,,9.081,1.652,
C CSP2 alkene (2),NN−O axoxy (deloc) (143),,3.800,0.827,,,0.317,,3.745,2.448,
C CSP2 alkene (2),N −N azoxy (deloc) (144),,5.200,1.395,,,0.656,,7.176,1.990,
C CSP2 carbonyl (3),C CSP2 carbonyl (3),,11.250,1.217,,,0.896,,4.082,2.505,
C CSP2 carbonyl (3),"H except on N, O, S (5)",,4.370,1.118,,,0.732,,4.861,1.728,
C CSP2 carbonyl (3),"O C−O−H, C−O−C, O−O (6)",,6.000,1.354,,,0.740,,5.482,2.014,
C CSP2 carbonyl (3),O OC carbonyl (7),,10.100,1.208,,,1.501,,12.653,1.834,
C CSP2 carbonyl (3),N NSP2 (9),,6.700,1.377,,,0.984,,6.778,1.845,
C CSP2 carbonyl (3),F fluoride (11),,4.200,1.381,,,0.852,,5.532,1.570,
C CSP2 carbonyl (3),Cl chloride (12),,2.880,1.816,,,0.842,,2.935,1.308,
C CSP2 carbonyl (3),Br bromide (13),,2.800,1.990,,,0.617,,2.436,1.506,
C CSP2 carbonyl (3),I iodide (14),,2.600,2.228,,,0.568,,1.970,1.513,
C CSP2 carbonyl (3),C cyclopropane (22),,4.400,1.447,,,0.803,,4.938,1.656,
C CSP2 carbonyl (3),O carboxylate ion (47),,7.035,1.276,,,1.130,,9.920,1.764,
C CSP2 carbonyl (3),C CSP3 cyclobutane (56),,4.800,1.509,,,0.728,,4.357,1.816,
C CSP2 carbonyl (3),C CSP2 cyclobutene (57),,9.600,1.351,,,0.751,,5.069,2.528,
C CSP2 carbonyl (3),"O O−H, O−C (carboxyl) (75)",,6.000,1.354,,,0.833,,6.401,1.897,
C CSP2 carbonyl (3),O OC−CO (76),,10.800,1.209,,,1.232,,12.009,2.094,
C CSP2 carbonyl (3),O OC−O−H (acid) (77),,9.800,1.214,,,1.597,,13.498,1.752,
C CSP2 carbonyl (3),O OC−O−C (ester) (78),,9.800,1.214,,,1.532,,12.741,1.788,
C CSP2 carbonyl (3),O OC−X (halide) (80),,11.650,1.204,,,1.625,,13.872,1.893,
C CSP2 carbonyl (3),O OC−CC< (81),,9.640,1.208,,,1.255,,11.118,1.960,
C CSP2 carbonyl (3),O OC−O−CO (82),,10.600,1.198,,,1.638,,13.967,1.799,
C CSP2 carbonyl (3),O OC(CC)(O−CO) (102),,9.600,1.204,,,1.581,,13.275,1.742,
C CSP2 carbonyl (3),O OC(CO)(CC<) (120),,10.800,1.209,,,1.137,,11.549,2.179,
C CSP2 carbonyl (3),O −O− anhydride (locl) (148),,4.300,1.405,,,0.749,,5.027,1.694,
C CSP alkyne (4),C CSP alkyne (4),,15.250,1.210,,,2.203,,16.345,1.860,
C CSP alkyne (4),N NSP (10),,17.330,1.158,,,1.959,,18.727,2.103,
C CSP alkyne (4),C CSP2 cyclobutene (57),,11.200,1.312,,,1.079,,5.756,2.279,
C CSP alkyne (4),H H−C acetylene (124),,5.970,1.080,,,1.079,,6.265,1.663,
"H except on N, O, S (5)",S+ >S+ sulfonium (16),,3.800,1.346,,,0.769,,3.945,1.572,
"H except on N, O, S (5)",S > SO sulfoxide (17),,3.170,1.372,,,0.518,,3.313,1.749,
"H except on N, O, S (5)",S > SO2 sulfone (18),,3.800,1.346,,,0.644,,3.649,1.718,
"H except on N, O, S (5)",Si silane (19),,2.650,1.483,,,0.777,,2.955,1.306,
"H except on N, O, S (5)",C cyclopropane (22),,5.080,1.086,,,0.877,,5.493,1.702,
"H except on N, O, S (5)",P > P- phosphine (25),,3.065,1.420,,,0.667,,3.328,1.516,
"H except on N, O, S (5)",Ge germanium (31),,2.550,1.529,,,0.689,,2.626,1.361,
"H except on N, O, S (5)",Sn tin (32),,2.229,1.696,,,0.662,,2.127,1.297,
"H except on N, O, S (5)",Pb lead (IV) (33),,1.894,1.775,,,0.549,,1.725,1.314,
"H except on N, O, S (5)",Se selenium (34),,3.170,1.472,,,0.693,,3.457,1.513,
"H except on N, O, S (5)",Te tellurium (35),,2.850,1.670,,,0.636,,2.736,1.497,
"H except on N, O, S (5)",C CSP2 cyclopropene (38),,4.600,1.072,,,0.913,,5.879,1.587,
"H except on N, O, S (5)",C benzene (localized) (50),,5.150,1.101,,,0.903,,5.436,1.689,
"H except on N, O, S (5)",C CSP3 cyclobutane (56),,4.740,1.112,,,0.834,,5.170,1.685,
"H except on N, O, S (5)",C CSP2 cyclobutene (57),,5.150,1.101,,,0.886,,5.468,1.705,
"H except on N, O, S (5)",P > PO phosphate (153),,3.280,1.398,,,0.719,,3.608,1.510,
"O C−O−H, C−O−C, O−O (6)","O C−O−H, C−O−C, O−O (6)",,3.950,1.448,,,0.401,,4.485,2.219,

atom type 1 (MM3 type number),atom type 2 (MM3 type number),kh/mdyne Å,−1,rh/Å,De/mdyne Å,k /mdyne Å/Å−1α −1,,α calc
"O C−O−H, C−O−C, O−O (6)",Si silane (19),5.050,,1.636,0.978,5.148,,1.607
"O C−O−H, C−O−C, O−O (6)",H  −OH alcohol (21),7.630,,0.947,0.914,8.386,,2.043
"O C−O−H, C−O−C, O−O (6)",H COOH carboxyl (24),7.150,,0.972,0.940,7.854,,1.951
"O C−O−H, C−O−C, O−O (6)",P > P− phosphine (25),2.900,,1.615,0.781,4.390,,1.363
"O C−O−H, C−O−C, O−O (6)",B > B− trigonal (26),4.619,,1.362,1.042,5.816,,1.488
"O C−O−H, C−O−C, O−O (6)",C CSP3 cyclobutane (56),2.800,,1.415,0.818,5.316,,1.308
"O C−O−H, C−O−C, O−O (6)",C CSP2 cyclobutene (57),6.000,,1.355,0.892,6.863,,1.834
"O C−O−H, C−O−C, O−O (6)",H H−O enol/phenol (73),7.200,,0.972,0.891,8.216,,2.010
"O C−O−H, C−O−C, O−O (6)",P >PO phosphate (153),5.300,,1.599,1.398,9.924,,1.377
O OC carbonyl (7),S > SO sulfoxide (17),7.100,,1.487,0.633,1.845,,2.369
O OC carbonyl (7),S > SO2 sulfone (18),9.420,,1.442,1.180,9.402,,1.998
O OC carbonyl (7),N nitro (46),7.500,,1.223,1.079,10.556,,1.864
O O=C CARBONYL (7),C C=O CYCLOBUTANONE (58),10.150,,1.202,1.558,13.099,,1.805
O O=C CARBONYL (7),C C=O CYCLOPROPANONE (67),11.420,,1.196,1.539,13.191,,1.926
O O=C CARBONYL (7),C =C=O KETENE (106),10.500,,1.165,1.667,15.588,,1.775
O OC carbonyl (7),P >PO phosphate (153),8.900,,1.487,1.341,10.415,,1.822
O OC carbonyl (7),S > SO2 sulfonamide (154),8.677,,1.463,1.181,9.937,,1.916
N NSP3 (8),H NH amine/imine (23),6.420,,1.015,0.885,7.128,,1.904
N NSP3 (8),C benzene (localized) (50),6.320,,1.378,0.965,6.262,,1.810
N NSP3 (8),C CSP3 cyclobutane (56),5.300,,1.448,0.846,5.270,,1.769
N NSP2 (9),S > SO2 sulfone (18),6.100,,1.660,0.899,5.108,,1.842
N NSP2 (9),H H−N−CO amide (28),6.770,,1.028,1.048,7.356,,1.797
S −S− sulfide (15),S  −S− sulfide (15),2.620,,2.019,0.429,2.890,,1.747
S −S− sulfide (15),H SH thiol (44),3.870,,1.342,0.905,24.559,,1.462
Si silane (19),Si silane (19),1.650,,2.324,0.672,1.918,,1.108
Si silane (19),C cyclopropane (22),3.500,,1.837,0.839,3.203,,1.444
Si silane (19),C CSP3 cyclobutane (56),1.300,,1.881,0.767,2.897,,0.921
H −OH alcohol (21),O > N−OH hydroxyamine (145),7.500,,0.974,0.824,8.418,,2.134
H −OH alcohol (21),O O−PO phosphate (159),7.780,,0.948,1.002,8.287,,1.970
C cyclopropane (22),C cyclopropane (22),5.000,,1.485,1.397,5.221,,1.338
C cyclopropane (22),Ge germanium (31),2.700,,1.911,0.752,2.835,,1.340
C cyclopropane (22),C CSP2 cyclopropene (38),4.400,,1.488,1.492,5.878,,1.214
C cyclopropane (22),N nitro (46),4.350,,1.478,0.610,4.214,,1.889
C cyclopropane (22),C CSP3 cyclobutane (56),4.400,,1.505,0.872,4.717,,1.588
H NH amine/imine (23),N NSP2 pyrrole (40),6.500,,1.030,1.027,7.238,,1.779
H NH amine/imine (23),NN−O azoxy (local) (43),5.520,,1.040,0.568,6.073,,2.205
H NH amine/imine (23),NN− imine (localized) (72),5.970,,1.019,0.735,6.585,,2.015
H NH amine/imine (23),N −N azoxy (local) (109),5.950,,1.028,0.718,6.883,,2.035
H NH amine/imine (23),N > N−OH hydroxyamine (146),6.150,,1.021,0.771,6.846,,1.998
H NH amine/imine (23),N NSP3 hydrazine (150),6.360,,1.021,0.774,6.814,,2.027
H NH amine/imine (23),N NSP3 sulfonamide (155),6.378,,1.020,0.957,7.023,,1.825
H COOH carboxyl (24),"O O−H, O−C (carboxyl) (75)",7.150,,0.974,0.934,7.996,,1.956
Ge germanium (31),Ge germanium (31),1.450,,2.404,0.542,2.038,,1.157
Pb lead (IV) (33),Pb lead (IV) (33),2.050,,1.944,0.509,0.891,,1.419
C CSP2 cyclopropene (38),C CSP2 cyclopropene (38),9.600,,1.303,0.613,3.431,,2.797
N+ NSP3 ammonium (39),N NSP2 pyrrole (40),11.000,,1.230,0.597,5.133,,3.034
N+ NSP3 ammonium (39),H ammonium (48),6.140,,1.053,0.861,6.329,,1.888
O OSP2 furan (41),H H−O enol/phenol (73),7.200,,0.960,0.883,8.460,,2.019
O OSP2 furan (41),N N−OH oxime (108),4.320,,1.404,0.533,4.792,,2.014
N N−O azoxy (local) (43),O amine oxide oxygen (69),8.800,,1.269,0.816,8.425,,2.322
N −N−O azoxy (local) (43),N −N azoxy (local) (109),7.100,,1.262,1.078,9.846,,1.815
C benzene (localized) (50),C benzene (localized) (50),6.560,,1.389,2.546,10.280,,1.135
C CSP3 cyclobutane (56),C CSP3 cyclobutane (56),4.490,,1.500,1.529,6.251,,1.212
C CSP2 cyclobutene (57),C CSP2 cyclobutene (57),7.500,,1.332,1.972,12.598,,1.379
O amine oxide oxygen (69),NN−O axoxy (deloc) (143),9.000,,1.282,0.639,5.299,,2.654
O >N−OH hydroxyamine (145),N > N−OH hydroxyamine (146),4.500,,1.405,0.571,5.132,,1.984
N NSP3 hydrazine (150),N NSP3 hydrazine (150),3.000,,1.549,0.634,5.372,,1.538
P >PO phosphate (153),O O−PO phosphate (159),5.700,,1.600,1.046,7.226,,1.651
S >SO2 sulfonamide (154),N NSP3 sulfonamide (155),3.944,,1.697,0.703,4.727,,1.674
"""
}
