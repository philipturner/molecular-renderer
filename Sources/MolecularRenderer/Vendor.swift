enum Vendor {
  case apple
  case nvidia
  case amd
  
  // We detect the vendor, but have no actual support
  // for wave8/wave16 mode because we don't have an
  // Intel Arc GPU to test.
  //
  // In June 2025, Intel discrete GPUs disappeared from
  // the market share. Instead, we'll target high-end
  // Intel integrated GPUs, on Windows only (not old
  // Intel Macs).
  //
  // The lineup of integrated GPUs doesn't seem
  // promising. The Wikipedia entry for 13th and 14th
  // generation Core suggests they're still using
  // UHD Graphics 770 (~742 GFLOPS) for the iGPUs.
  // We should clarify how much of the mobile market
  // share of iGPUs is based on the higher-performance
  // Arc architecture.
  //
  // We only need to perform on par with the M1 (2.6 TFLOPS)
  // or GTX 970 (3.9 TFLOPS). In addition, we need to
  // make AMD FSR 3 work on the Intel integrated GPUs.
  // There are also concerns with OpenMM and/or MM4 (which
  // may switch to a Swift translation of OpenMM around 1
  // year down the road).
  case intel
}
