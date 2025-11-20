enum Vendor {
  case apple
  case nvidia
  case amd
  
  // We detect the vendor, but have no actual support
  // for wave8/wave16 mode because we don't have an
  // Intel Arc GPU to test.
  case intel
  
}
