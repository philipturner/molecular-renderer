mkdir .build
cd .build

curl -L -o "xtb-macos.zip" "https://drive.google.com/uc?export=download&id=1QK3Wc5EDm3T-tLBDnujAgXLxenLghmtY"
unzip -o xtb-macos.zip

cd ../ # balance 'cd .build'

cp ".build/xtb-macos/libxtb.dylib" libxtb.dylib
