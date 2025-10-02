mkdir .build
cd .build

curl -L -o "openmm-macos.zip" "https://drive.google.com/uc?export=download&id=1GkOZm8CR8ezRtOgvrittQMbny_fT3HXd"
unzip openmm-macos.zip

cp openmm-macos/libOpenMM.dylib ../libOpenMM.dylib
