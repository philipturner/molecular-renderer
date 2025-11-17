mkdir .build

## Download each binary dependency from the Internet.

cd .build

curl -L -o "openmm-macos.zip" "https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.1/openmm-macos.zip"
unzip -o openmm-macos.zip

curl -L -o "xtb-macos.zip" "https://github.com/philipturner/molecular-renderer-simulator-binaries/releases/download/v1.0.1/xtb-macos.zip"
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
# cp ".build/xtb-macos/libgcc_s.1.1.dylib" libgcc_s.1.1.dylib
cp ".build/xtb-macos/libgfortran.5.dylib" libgfortran.5.dylib
cp ".build/xtb-macos/libgomp.1.dylib" libgomp.1.dylib
cp ".build/xtb-macos/libquadmath.0.dylib" libquadmath.0.dylib

# Sanitize the folder from this unused library.
rm -rf ".build/xtb-macos/libgcc_s.1.1.dylib"

## Fix the self-link of each library.

# Technically, "-id" command is not needed for "libxtb.dylib". However, it
# prevents an issue where macOS flags libxtb as a virus, when copying the binary
# from an external folder instead of generating the folder's contents via unzip.

install_name_tool -id "libc++.1.dylib" libc++.1.dylib
install_name_tool -id "libocl_icd_wrapper_apple.dylib" libocl_icd_wrapper_apple.dylib
install_name_tool -id "libOpenCL.1.dylib" libOpenCL.1.dylib
install_name_tool -id "libOpenMM.dylib" libOpenMM.dylib
install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
install_name_tool -id "libxtb.dylib" libxtb.dylib
# install_name_tool -id "libgcc_s.1.1.dylib" libgcc_s.1.1.dylib
install_name_tool -id "libgfortran.5.dylib" libgfortran.5.dylib
install_name_tool -id "libgomp.1.dylib" libgomp.1.dylib
install_name_tool -id "libquadmath.0.dylib" libquadmath.0.dylib

## Fix the symbolic links between libraries.

install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMM.dylib
install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenCL.1.dylib" "$(pwd)/libOpenCL.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenMM.dylib" "$(pwd)/libOpenMM.dylib" libOpenMMOpenCL.dylib

export GCC="/opt/homebrew/opt/gcc/lib/gcc/current"
install_name_tool -change "$GCC/libgfortran.5.dylib" "$(pwd)/libgfortran.5.dylib" libxtb.dylib
install_name_tool -change "$GCC/libgomp.1.dylib" "$(pwd)/libgomp.1.dylib" libxtb.dylib
install_name_tool -change "$GCC/libquadmath.0.dylib" "$(pwd)/libquadmath.0.dylib" libxtb.dylib

# I can fix one of the faulty rpaths, but not both. I'll check whether all
# tests of Molecular Renderer still work, including some GFN-FF tests, on a
# weirdly configured M4 Pro Mac Mini.
#
# error: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/install_name_tool: changing install names or rpaths can't be redone for: libgfortran.5.dylib (for architecture arm64) because larger updated load commands do not fit (the program must be relinked, and you may need to use -headerpad or -headerpad_max_install_names)
#
# install_name_tool -change "@rpath/libgcc_s.1.1.dylib" "$(pwd)/libgcc_s.1.1.dylib" libgfortran.5.dylib
# install_name_tool -change "@rpath/libquadmath.0.dylib" "$(pwd)/libquadmath.0.dylib" libgfortran.5.dylib

## Repair the code signature.

codesign -fs - libc++.1.dylib
codesign -fs - libocl_icd_wrapper_apple.dylib
codesign -fs - libOpenCL.1.dylib
codesign -fs - libOpenMM.dylib
codesign -fs - libOpenMMOpenCL.dylib
codesign -fs - libxtb.dylib
# codesign -fs - libgcc_s.1.1.dylib
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
# codesign --verify --verbose libgcc_s.1.1.dylib
codesign --verify --verbose libgfortran.5.dylib
codesign --verify --verbose libgomp.1.dylib
codesign --verify --verbose libquadmath.0.dylib
