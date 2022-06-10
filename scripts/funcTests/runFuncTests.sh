#!/usr/bin/env bash

echo "Starting runFuncTests at `date -u +"%Y-%m-%dT%H:%M:%S"`"
echo ".NET Channel arg: $1"
env | sort

while true ; do
	case "$1" in
		-c|--clear-cache) CLEAR_CACHE=1 ; shift ;;
		--) shift ; break ;;
		*) shift ; break ;;
	esac
done

RESULTCODE=0

# print openssl version
echo "==================================================================================================="
openssl version -a
echo "==================================================================================================="
# move up to the repo root
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR=$SCRIPTDIR/../..
pushd $DIR/

mono --version

dotnet --info

# Download the CLI install script to cli
echo "Installing dotnet CLI"
mkdir -p cli
curl -o cli/dotnet-install.sh -L https://dot.net/v1/dotnet-install.sh

# Run install.sh
chmod +x cli/dotnet-install.sh

# Get recommended version for bootstrapping testing version

echo "cli/dotnet-install.sh --install-dir cli --runtime dotnet --channel 3.1 -nopath"
cli/dotnet-install.sh --install-dir cli --runtime dotnet --channel 3.1 -nopath

echo "cli/dotnet-install.sh --install-dir cli --runtime dotnet --channel 5.0 -nopath"
cli/dotnet-install.sh --install-dir cli --runtime dotnet --channel 5.0 -nopath

if (( $? )); then
	echo "The .NET CLI Install failed!!"
	exit 1
fi

# Disable .NET CLI Install Lookup
DOTNET_MULTILEVEL_LOOKUP=0

DOTNET="$(pwd)/cli/dotnet"

# Let the dotnet cli expand and decompress first if it's a first-run
$DOTNET --info

# Get CLI Branches for testing
echo "dotnet msbuild build/config.props /v:m /nologo /t:GetCliBranchForTesting"

IFS=$'\n'
CMD_OUT_LINES=(`dotnet msbuild build/config.props /v:m /nologo /t:GetCliBranchForTesting`)
# Take only last the line which has the version information and strip all the spaces
CMD_LAST_LINE=${CMD_OUT_LINES[@]:(-1)}
DOTNET_BRANCHES=${CMD_LAST_LINE//[[:space:]]}
unset IFS

echo "cli/dotnet-install.sh --install-dir cli --channel $1 --quality GA  -nopath"
cli/dotnet-install.sh --install-dir cli --channel $1 --quality GA  -nopath


# Display .NET CLI info
$DOTNET --info

echo "initial dotnet cli install finished at `date -u +"%Y-%m-%dT%H:%M:%S"`"

echo "================="

echo "Deleting .NET Core temporary files"
rm -rf "/tmp/"dotnet.*

echo "second dotnet cli install finished at `date -u +"%Y-%m-%dT%H:%M:%S"`"
echo "================="

#restore solution packages
dotnet msbuild -t:restore "$DIR/build/bootstrap.proj" -bl:"$BUILD_STAGINGDIRECTORY/binlog/01.RestoreBootstrap.binlog"
if [ $? -ne 0 ]; then
	echo "Restore failed!!"
	exit 1
fi

echo "bootstrap project restore finished at `date -u +"%Y-%m-%dT%H:%M:%S"`"

# init the repo

git submodule init
git submodule update

echo "git submodules updated finished at `date -u +"%Y-%m-%dT%H:%M:%S"`"

# clear caches
if [ "$CLEAR_CACHE" == "1" ]
then
	# echo "Clearing the nuget web cache folder"
	# rm -r -f ~/.local/share/NuGet/*

	echo "Clearing the nuget packages folder"
	rm -r -f ~/.nuget/packages/*
fi

# restore packages
echo "dotnet msbuild build/build.proj /t:Restore /p:VisualStudioVersion=16.0 /p:Configuration=Release /p:BuildNumber=1 /p:ReleaseLabel=beta /bl:$BUILD_STAGINGDIRECTORY/binlog/02.Restore.binlog"
dotnet msbuild build/build.proj /t:Restore /p:VisualStudioVersion=16.0 /p:Configuration=Release /p:BuildNumber=1 /p:ReleaseLabel=beta /bl:$BUILD_STAGINGDIRECTORY/binlog/02.Restore.binlog

if [ $? -ne 0 ]; then
	echo "Restore failed!!"
	exit 1
fi

echo "Restore finished at `date -u +"%Y-%m-%dT%H:%M:%S"`"

# Unit tests
echo "dotnet msbuild build/build.proj /t:CoreUnitTests /p:VisualStudioVersion=16.0 /p:Configuration=Release /p:BuildNumber=1 /p:ReleaseLabel=beta /bl:$BUILD_STAGINGDIRECTORY/binlog/03.CoreUnitTests.binlog"
dotnet msbuild build/build.proj /t:CoreUnitTests /p:VisualStudioVersion=16.0 /p:Configuration=Release /p:BuildNumber=1 /p:ReleaseLabel=beta /bl:$BUILD_STAGINGDIRECTORY/binlog/03.CoreUnitTests.binlog

if [ $? -ne 0 ]; then
	echo "CoreUnitTests failed!!"
	RESULTCODE=1
fi

echo "Core tests finished at `date -u +"%Y-%m-%dT%H:%M:%S"`"

#Clean System dll
rm -rf "$TestDir/System.*" "$TestDir/WindowsBase.dll" "$TestDir/Microsoft.CSharp.dll" "$TestDir/Microsoft.Build.Engine.dll"

popd

exit $RESULTCODE
