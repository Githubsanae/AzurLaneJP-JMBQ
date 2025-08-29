#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Download apkeep
get_artifact_download_url () {
    # Usage: get_download_url <repo_name> <artifact_name> <file_type>
    local api_url="https://api.github.com/repos/$1/releases/latest"
    # Use -s for silent, -f to fail silently on server errors
    local result=$(curl -sfL $api_url | jq ".assets[] | select(.name | contains(\"$2\") and contains(\"$3\") and (contains(\".sig\") | not)) | .browser_download_url")
    echo ${result:1:-1}
}

# Artifacts associative array aka dictionary
declare -A artifacts

artifacts["apkeep"]="EFForg/apkeep apkeep-x86_64-unknown-linux-gnu"
artifacts["apktool.jar"]="iBotPeaches/Apktool apktool .jar"

# Fetch all the dependencies
for artifact in "${!artifacts[@]}"; do
    if [ ! -f $artifact ]; then
        echo "Downloading $artifact"
        url=$(get_artifact_download_url ${artifacts[$artifact]})
        if [ -z "$url" ]; then
            echo "Error: Could not get download URL for $artifact"
            exit 1
        fi
        curl -L -o $artifact "$url"
    fi
done

chmod +x apkeep
# Download Azur Lane
download_azurlane () {
    if [ ! -f "com.YoStarJP.AzurLane" ]; then
    ./apkeep -a com.YoStarJP.AzurLane .
    fi
}
# Download Azur Lane
echo "Get Azur Lane apk"
if [ ! -f "com.YoStarJP.AzurLane" ]; then
    echo "Get Azur Lane apk"
    download_azurlane
    unzip -o com.YoStarJP.AzurLane.xapk -d AzurLane
    cp AzurLane/com.YoStarJP.AzurLane.apk .
fi

# Download JMBQ
if [ ! -d "azurlane" ]; then
    echo "Downloading JMBQ"
    git clone https://github.com/feathers-l/azurlane
fi

echo "Decompile Azur Lane apk"
java -jar apktool.jar d -f -q com.YoStarJP.AzurLane.apk

DECOMPILED_DIR="com.YoStarJP.AzurLane"
if [ ! -d "$DECOMPILED_DIR" ]; then
    echo "Error: Decompilation failed. Directory '$DECOMPILED_DIR' not found."
    exit 1
fi

echo "Copy JMBQ libs"
cp -r azurlane/. "$DECOMPILED_DIR/lib/"

echo "Patching Azur Lane with JMBQ"
# Find the UnityPlayerActivity.smali file automatically
smali_file=$(find "$DECOMPILED_DIR" -name "UnityPlayerActivity.smali" | head -n 1)

if [ -z "$smali_file" ]; then
    echo "Error: Could not find UnityPlayerActivity.smali in decompiled files."
    exit 1
fi
echo "Found smali file at: $smali_file"

# Find the line with the onCreate method definition
oncreate_pattern=$(grep -m 1 '.method public onCreate(Landroid/os/Bundle;)V' "$smali_file")

if [ -z "$oncreate_pattern" ]; then
    echo "Error: Could not find onCreate method in $smali_file"
    exit 1
fi

# Define the code to inject
# The empty lines are for readability in the smali file
injection_code="\n\n    const-string v0, \"JMBQ\"\n\n    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V"

# Use a temporary file for sed to handle special characters in the pattern
echo "$oncreate_pattern" > pattern.txt
sed -i.bak "/$(sed 's/[/&]/\\&/g' pattern.txt)/a\\$injection_code" "$smali_file"
rm pattern.txt
rm "$smali_file.bak"

echo "Patch applied successfully."

echo "Build Patched Azur Lane apk"
java -jar apktool.jar b -f -q "$DECOMPILED_DIR" -o build/com.YoStarJP.AzurLane.patched.apk

echo "Set Github Release version"
s=($(/apkeep -a com.YoStarJP.AzurLane -l))
if [ ${#s[@]} -gt 0 ]; then
    echo "PERSEUS_VERSION=$(echo ${s[-1]})" >> $GITHUB_ENV
else
    echo "Warning: Could not determine app version from apkeep."
fi

echo "Done."
