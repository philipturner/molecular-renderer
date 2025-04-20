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

















