#mkdir .build
#cd .build
#
#curl -L -o "openmm-macos.zip" "https://drive.google.com/uc?export=download&id=1GkOZm8CR8ezRtOgvrittQMbny_fT3HXd"
#unzip -o openmm-macos.zip
#
#cd ../ # balance 'cd .build'
#
#cp ".build/openmm-macos/libc++.1.dylib" libc++.1.dylib
#cp ".build/openmm-macos/libOpenCL.1.dylib" libOpenCL.1.dylib
#cp ".build/openmm-macos/libOpenMM.dylib" libOpenMM.dylib
#cp ".build/openmm-macos/libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
#
#install_name_tool -id "libc++.1.dylib" libc++.1.dylib
#install_name_tool -id "libOpenCL.1.dylib" libOpenCL.1.dylib
#install_name_tool -id "libOpenMM.dylib" libOpenMM.dylib
#install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
#
#install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMM.dylib
#install_name_tool -change "@rpath/libc++.1.dylib" "$(pwd)/libc++.1.dylib" libOpenMMOpenCL.dylib
#install_name_tool -change "@rpath/libOpenCL.1.dylib" "$(pwd)/libOpenCL.1.dylib" libOpenMMOpenCL.dylib
#install_name_tool -change "@rpath/libOpenMM.dylib" "$(pwd)/libOpenMM.dylib" libOpenMMOpenCL.dylib
#
#codesign -fs - libc++.1.dylib
#codesign -fs - libOpenCL.1.dylib
#codesign -fs - libOpenMM.dylib
#codesign -fs - libOpenMMOpenCL.dylib
#
#echo "These code-signs should report success:"
#codesign --verify --verbose libc++.1.dylib
#codesign --verify --verbose libOpenCL.1.dylib
#codesign --verify --verbose libOpenMM.dylib
#codesign --verify --verbose libOpenMMOpenCL.dylib

export MINIFORGE_DIR="/Users/philipturner/miniforge3/lib"
cp "$MINIFORGE_DIR/libOpenMM.dylib" libOpenMM.dylib
cp "$MINIFORGE_DIR/libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib

install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libc++.1.dylib" "$MINIFORGE_DIR/libc++.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenCL.1.dylib" "$MINIFORGE_DIR/libOpenCL.1.dylib" libOpenMMOpenCL.dylib
install_name_tool -change "@rpath/libOpenMM.dylib" "$(pwd)/libOpenMM.dylib" libOpenMMOpenCL.dylib

codesign -fs - libOpenMMOpenCL.dylib

echo "These code-signs should report success:"
codesign --verify --verbose libOpenMMOpenCL.dylib


