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
oncreate=$(grep -n -m 1 'onCreate'  com.YoStarJP.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali | sed  's/[0-9]*\:\(.*\)/\1/')
sed -ir "N; s#\($oncreate\n    .locals 2\)#\1\n    const-string v0, \"JMBQ\"\n\n    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V\n#" com.YoStarJP.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali

echo "Build Patched Azur Lane apk"
java -jar apktool.jar b -q -f com.YoStarJP.AzurLane -o build/com.YoStarJP.AzurLane.patched.apk

echo "Set Github Release version"
s=($(./apkeep -a com.YoStarJP.AzurLane -l .))
echo "PERSEUS_VERSION=$(echo ${s[-1]})" >> $GITHUB_ENV
