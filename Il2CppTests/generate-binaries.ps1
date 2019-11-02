﻿# Copyright 2019 Katy Coe - http://www.hearthcode.org - http://www.djkaty.com
# All rights reserved.

# Compile all of the test items in TestSources via IL2CPP to produce the binaries necessary to run the tests
# Requires Unity 2019.2.8f1 or later and Visual Studio 2017 (or MSBuild with C# 7+ support) or later to be installed
# Requires Android NDK r13b or newer for Android test builds (https://developer.android.com/ndk/downloads)

# Path to C¤ compiler (14.0 = Visual Studio 2017, 15.0 = Visual Studio 2019 etc.)
$CSC = (gci 'C:\Program Files (x86)\MSBuild\*\Bin\csc.exe' | sort FullName)[-1].FullName

# Path to latest installed version of Unity
# The introduction of Unity Hub changed the base path of the Unity editor
$UnityPath = (gci 'C:\Program Files\Unity\Hub\Editor\*\Editor\Data' | sort FullName)[-1].FullName

# Calculate Unity paths
$il2cpp = $UnityPath + '\il2cpp\build\il2cpp.exe'
$mscorlib = $UnityPath + '\Mono\lib\mono\unity\mscorlib.dll'
$AndroidPlayer = $UnityPath + '\PlaybackEngines\AndroidPlayer'

# Path to the Android NDK
# Different Unity versions require specific NDKs, see the section Change the NDK at:
# The NDK can also be installed standalone without AndroidPlayer
# https://docs.unity3d.com/2019.1/Documentation/Manual/android-sdksetup.html
$AndroidNDK = $AndroidPlayer + '\NDK'

# Check that everything is installed
if (!(Test-Path -Path $CSC -PathType leaf)) {
	echo "Could not find C¤ compiler csc.exe at '$CSC' - aborting"
	Exit
} else {
	echo "Using C# compiler at '$CSC'"
}

if (!(Test-Path -Path $UnityPath -PathType container)) {
	echo "Could not find Unity editor at '$UnityPath' - aborting"
	Exit
} else {
	echo "Using Unity installation at '$UnityPath'"
}

if (!(Test-Path -Path $AndroidNDK -PathType container)) {
	echo "Could not find Android NDK at '$AndroidNDK' - aborting"
	Exit
}
if (!(Test-Path -Path $il2cpp -PathType leaf)) {
	echo "Could not find Unity IL2CPP build support - aborting"
	Exit
}
if (!(Test-Path -Path $AndroidPlayer -PathType container)) {
	echo "Could not find Unity Android build support - aborting"
	Exit
}

# Workspace paths
$src = "$PSScriptRoot/TestSources"
$asm = "$PSScriptRoot/TestAssemblies"
$bin = "$PSScriptRoot/TestBinaries"

# We try to make the arguments as close as possible to a real Unity build
# "--lump-runtime-library" was added to reduce the number of C++ files generated by UnityEngine (Unity 2019)
$arg =	'--convert-to-cpp', '--compile-cpp', '--libil2cpp-static', '--configuration=Release', `
		'--emit-null-checks', '--enable-array-bounds-check', '--forcerebuild', `
		'--map-file-parser=$UnityPath\il2cpp\MapFileParser\MapFileParser.exe'

# Prepare output folders
md $asm, $bin 2>&1 >$null

# Compile all .cs files in TestSources
echo "Compiling source code..."
gci $src | % { & $csc "/t:library" "/nologo" "/out:$asm/$($_.BaseName).dll" "$src/$_" }

# Run IL2CPP on all generated assemblies for both x86 and ARM
# Earlier builds of Unity included mscorlib.dll automatically; in current versions we must specify its location
gci $asm | % {
	# x86
	$name = "GameAssembly-$($_.BaseName)-x86"
	echo "Running il2cpp for test assembly $name (Windows/x86)..."
	md $bin/$name 2>&1 >$null
	& $il2cpp $arg '--platform=WindowsDesktop', '--architecture=x86', `
				"--assembly=$asm/$_,$mscorlib", `
				"--outputpath=$bin/$name/$name.dll"
	mv -Force $bin/$name/Data/metadata/global-metadata.dat $bin/$name
	rm -Force -Recurse $bin/$name/Data

	# x64
	$name = "GameAssembly-$($_.BaseName)-x64"
	echo "Running il2cpp for test assembly $name (Windows/x64)..."
	md $bin/$name 2>&1 >$null
	& $il2cpp $arg '--platform=WindowsDesktop', '--architecture=x64', `
				"--assembly=$asm/$_,$mscorlib", `
				"--outputpath=$bin/$name/$name.dll"
	mv -Force $bin/$name/Data/metadata/global-metadata.dat $bin/$name
	rm -Force -Recurse $bin/$name/Data

	# ARM
	$name = "$($_.BaseName)"
	echo "Running il2cpp for test assembly $name (Android/ARMv7)..."
	md $bin/$name 2>&1 >$null
	& $il2cpp $arg '--platform=Android', '--architecture=ARMv7', `
				"--assembly=$asm/$_,$mscorlib", `
				"--outputpath=$bin/$name/$name.so", `
				"--additional-include-directories=$AndroidPlayer/Tools/bdwgc/include" `
				"--additional-include-directories=$AndroidPlayer/Tools/libil2cpp/include" `
				"--tool-chain-path=$AndroidNDK"
	mv -Force $bin/$name/Data/metadata/global-metadata.dat $bin/$name
	rm -Force -Recurse $bin/$name/Data
}

# Generate test stubs
& "$PSScriptRoot/generate-tests.ps1"
