# This is the only part of OpenMM that I couldn't isolate from Miniforge.
# Luckily, configuring it requires no file URLs to the Miniforge directory.
conda install -c conda-forge ocl_icd_wrapper_apple --yes

mkdir .build
cd .build

curl -L -o "openmm-macos.zip" "https://drive.google.com/uc?export=download&id=1GkOZm8CR8ezRtOgvrittQMbny_fT3HXd"
unzip -o openmm-macos.zip

cd ../ # balance 'cd .build'

cp ".build/openmm-macos/libc++.1.dylib" libc++.1.dylib
cp ".build/openmm-macos/libOpenCL.1.dylib" libOpenCL.1.dylib
cp ".build/openmm-macos/libOpenMM.dylib" libOpenMM.dylib
cp ".build/openmm-macos/libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib

install_name_tool -id "libc++.1.dylib" libc++.1.dylib
install_name_tool -id "libOpenCL.1.dylib" libOpenCL.1.dylib
install_name_tool -id "libOpenMM.dylib" libOpenMM.dylib
install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib

install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMM.dylib
install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenCL.1.dylib" "$(pwd)/libOpenCL.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenMM.dylib" "$(pwd)/libOpenMM.dylib" libOpenMMOpenCL.dylib

codesign -fs - libc++.1.dylib
codesign -fs - libOpenCL.1.dylib
codesign -fs - libOpenMM.dylib
codesign -fs - libOpenMMOpenCL.dylib

echo "These code-signs should report success:"
codesign --verify --verbose libc++.1.dylib
codesign --verify --verbose libOpenCL.1.dylib
codesign --verify --verbose libOpenMM.dylib
codesign --verify --verbose libOpenMMOpenCL.dylib
