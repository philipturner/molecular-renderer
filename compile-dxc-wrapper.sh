# Select the right Clang executable. There could be many on the system, for
# example if AMD ROCm is installed.
swift_executable_path=$(which swift)
swift_toolchain_bin_dir="${swift_executable_path::-6}"
clang_executable_path="${swift_toolchain_bin_dir}/clang++"

# Check that Clang is detected.
echo "Output of 'clang++ --version':"
echo ""
$clang_executable_path --version
echo ""

# Compile the binaries.
#
# The '.build' folder should already exist, if the 'dxcompiler' binaries have
# been downloaded.
$clang_executable_path "Sources/DXCWrapper/DXCWrapper.cpp" -c -o ".build/dxcompiler_wrapper.o"
$clang_executable_path ".build/dxcompiler_wrapper.o" -shared -ldxcompiler -o dxcompiler_wrapper.dll
