# Automatic caching feature: return early if already compiled.
# if [ -f dxcompiler_wrapper.dll ]; then
#   exit 0
# fi

# Select the right Clang executable. There could be many on the system, for
# example if AMD ROCm is installed.
swift_executable_path=$(which swift)
swift_toolchain_bin_dir="${swift_executable_path::-6}"
clang_executable_path="${swift_toolchain_bin_dir}/clang++"
ar_executable_path="${swift_toolchain_bin_dir}/llvm-ar"

# Check that Clang is detected.
echo "Output of 'clang++ --version':"
echo ""
$clang_executable_path --version
echo ""

# Compile the binaries.
#
# The '.build' folder should already exist, if the 'dxcompiler' binaries have
# been downloaded.
$clang_executable_path -c -o ".build/dxcompiler_wrapper.o" "Sources/DXC/DXCWrapper.cpp"
$clang_executable_path -shared -ldxcompiler -o dxcompiler_wrapper.dll ".build/dxcompiler_wrapper.o"
$ar_executable_path r dxcompiler_wrapper.lib ".build/dxcompiler_wrapper.o"

# When both 'clang++ -static' (for the .dll) and 'llvm-ar r' (for the .lib) are
# run, in either order. With the contents of the other command's execution in
# the same directory. The compiler mysteriously creates a special '.exp' file.
# When this event happens, the two binaries are suddenly compatible with Swift
# and link to create a running executable.
#
# You can delete the '.exp' file and the .dll/.lib still create a working
# executable. I hypothesize that the compiler overrides the '.lib' file with
# an upgraded one that will correctly link to an external application.
#
# Check that the '.exp' file exists.
if [ -f dxcompiler_wrapper.exp ]; then
  echo "The file '.exp' exists."
  rm -f dxcompiler_wrapper.exp
else
  echo "The file '.exp' does not exist."
  exit -1
fi
