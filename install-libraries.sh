mkdir .build

## Download each binary dependency from the Internet.

cd .build

curl -L -o "openmm-macos.zip" "https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.2/openmm-macos.zip"
unzip -o openmm-macos.zip

curl -L -o "xtb-macos.zip" "https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.2/xtb-macos.zip"
unzip -o xtb-macos.zip

cd ../ # balance 'cd .build'

## Establish the vendors directory.

mkdir .build/vendors
cp ".build/openmm-macos/vendors/apple.icd" ".build/vendors/apple.icd"

## Copy binaries into the package folder.

cp ".build/openmm-macos/libc++.1.dylib" libc++.1.dylib
cp ".build/openmm-macos/libocl_icd_wrapper_apple.dylib" libocl_icd_wrapper_apple.dylib
cp ".build/openmm-macos/libOpenCL.1.dylib" libOpenCL.1.dylib
cp ".build/openmm-macos/libOpenMM.dylib" libOpenMM.dylib
cp ".build/openmm-macos/libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
cp ".build/xtb-macos/libxtb.dylib" libxtb.dylib
cp ".build/xtb-macos/libgcc_s.1.1.dylib" libgcc_s.1.1.dylib
cp ".build/xtb-macos/libgfortran.5.dylib" libgfortran.5.dylib
cp ".build/xtb-macos/libgomp.1.dylib" libgomp.1.dylib
cp ".build/xtb-macos/libquadmath.0.dylib" libquadmath.0.dylib

## Fix the self-link of each library.

# The "-id" command is required for "libOpenMM.dylib". The Workspace executable
# records this name when it links OpenMM. A bare file name is resolved relative
# to the current directory, so 'run.sh' must start from the package folder.
#
# Technically, "-id" command is not needed for the other libraries. However, it
# prevents an issue where macOS flags libxtb as a virus, when copying the binary
# from an external folder instead of generating the folder's contents via unzip.

install_name_tool -id "libc++.1.dylib" libc++.1.dylib
install_name_tool -id "libocl_icd_wrapper_apple.dylib" libocl_icd_wrapper_apple.dylib
install_name_tool -id "libOpenCL.1.dylib" libOpenCL.1.dylib
install_name_tool -id "libOpenMM.dylib" libOpenMM.dylib
install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
install_name_tool -id "libxtb.dylib" libxtb.dylib
install_name_tool -id "libgcc_s.1.1.dylib" libgcc_s.1.1.dylib
install_name_tool -id "libgfortran.5.dylib" libgfortran.5.dylib
install_name_tool -id "libgomp.1.dylib" libgomp.1.dylib
install_name_tool -id "libquadmath.0.dylib" libquadmath.0.dylib

## Fix the search path of the OpenMM plugin.

# OpenMM normally keeps libOpenMMOpenCL in a "plugins" subfolder, so it searches
# the parent folder for its dependencies. Here, the parent of the package
# folder could contain other copies of libOpenMM. Search the package folder.
#
# Every other library already searches its own folder ("@loader_path").

install_name_tool -rpath "@loader_path/../" "@loader_path/" libOpenMMOpenCL.dylib

## Repair the code signature.

codesign -fs - libc++.1.dylib
codesign -fs - libocl_icd_wrapper_apple.dylib
codesign -fs - libOpenCL.1.dylib
codesign -fs - libOpenMM.dylib
codesign -fs - libOpenMMOpenCL.dylib
codesign -fs - libxtb.dylib
codesign -fs - libgcc_s.1.1.dylib
codesign -fs - libgfortran.5.dylib
codesign -fs - libgomp.1.dylib
codesign -fs - libquadmath.0.dylib

echo "These code-signs should report success:"
codesign --verify --verbose libc++.1.dylib
codesign --verify --verbose libocl_icd_wrapper_apple.dylib
codesign --verify --verbose libOpenCL.1.dylib
codesign --verify --verbose libOpenMM.dylib
codesign --verify --verbose libOpenMMOpenCL.dylib
codesign --verify --verbose libxtb.dylib
codesign --verify --verbose libgcc_s.1.1.dylib
codesign --verify --verbose libgfortran.5.dylib
codesign --verify --verbose libgomp.1.dylib
codesign --verify --verbose libquadmath.0.dylib
