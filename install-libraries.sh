mkdir .build
cd .build

curl -L -o "openmm-macos.zip" "https://drive.google.com/uc?export=download&id=1GkOZm8CR8ezRtOgvrittQMbny_fT3HXd"
unzip -o openmm-macos.zip

cd ../ # balance 'cd .build'

cp ".build/openmm-macos/libOpenMM.dylib" libOpenMM.dylib
cp ".build/openmm-macos/libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib

install_name_tool -id "libOpenMM.dylib" libOpenMM.dylib
install_name_tool -id "libOpenMMOpenCL.dylib" libOpenMMOpenCL.dylib

codesign -fs - libOpenMM.dylib
codesign -fs - libOpenMMOpenCL.dylib

echo "These code-signs should report success:"
codesign --verify --verbose libOpenMM.dylib
codesign --verify --verbose libOpenMMOpenCL.dylib
