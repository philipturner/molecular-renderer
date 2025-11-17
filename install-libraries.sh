mkdir .build

## Download each binary dependency from the Internet.

cd .build

# curl -L -o "openmm-macos.zip" "https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.0/openmm-macos.zip"
# unzip -o openmm-macos.zip
cp -r "/Users/philipturner/Desktop/openmm-macos" "openmm-macos"

# curl -L -o "xtb-macos.zip" "https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.0/xtb-macos.zip"
# unzip -o xtb-macos.zip
cp -r "/Users/philipturner/Desktop/xtb-macos" "xtb-macos"

cd ../ # balance 'cd .build'

## Establish the vendors directory.

mkdir .build/vendors
cp ".build/openmm-macos/vendors/apple.icd" ".build/vendors/apple.icd"

## Copy binaries into the package folder.

cp ".build/openmm-macos/libc++.1.dylib" libc++.1.dylib
cp ".build/openmm-macos/libOpenCL.1.dylib" libOpenCL.1.dylib
cp ".build/openmm-macos/libOpenMM.dylib" libOpenMM.dylib
cp ".build/openmm-macos/libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
cp ".build/openmm-macos/libocl_icd_wrapper_apple.dylib" libocl_icd_wrapper_apple.dylib
cp ".build/xtb-macos/libxtb.dylib" libxtb.dylib

## Fix the symbolic links.

# Technically, "-id" command is not needed for "libxtb.dylib". However, it
# prevents an issue where macOS flags libxtb as a virus, when copying the binary
# from an external folder instead of generating the folder's contents via unzip.

install_name_tool -id "libc++.1.dylib" libc++.1.dylib
install_name_tool -id "libOpenCL.1.dylib" libOpenCL.1.dylib
install_name_tool -id "libOpenMM.dylib" libOpenMM.dylib
install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
install_name_tool -id "libocl_icd_wrapper_apple.dylib" libocl_icd_wrapper_apple.dylib
install_name_tool -id "libxtb.dylib" libxtb.dylib

install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMM.dylib
install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenCL.1.dylib" "$(pwd)/libOpenCL.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenMM.dylib" "$(pwd)/libOpenMM.dylib" libOpenMMOpenCL.dylib

  /opt/homebrew/opt/gcc/lib/gcc/current/libgomp.1.dylib (compatibility version 2.0.0, current version 2.0.0)
  /opt/homebrew/opt/gcc/lib/gcc/current/libgfortran.5.dylib (compatibility version 6.0.0, current version 6.0.0)
  /System/Library/Frameworks/Accelerate.framework/Versions/A/Accelerate (compatibility version 1.0.0, current version 4.0.0)
  /opt/homebrew/opt/gcc/lib/gcc/current/libquadmath.0.dylib (compatibility version 1.0.0, current version 1.0.0)

## Repair the code signature.

codesign -fs - libc++.1.dylib
codesign -fs - libOpenCL.1.dylib
codesign -fs - libOpenMM.dylib
codesign -fs - libOpenMMOpenCL.dylib
codesign -fs - libocl_icd_wrapper_apple.dylib
codesign -fs - libxtb.dylib

echo "These code-signs should report success:"
codesign --verify --verbose libc++.1.dylib
codesign --verify --verbose libOpenCL.1.dylib
codesign --verify --verbose libOpenMM.dylib
codesign --verify --verbose libOpenMMOpenCL.dylib
codesign --verify --verbose libocl_icd_wrapper_apple.dylib
codesign --verify --verbose libxtb.dylib
