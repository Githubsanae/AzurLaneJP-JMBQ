#!/bin/bash

# Download apkeep
get_artifact_download_url () {
    # Usage: get_download_url <repo_name> <artifact_name> <file_type>
    local api_url="https://api.github.com/repos/$1/releases/latest"
    local result=$(curl -s $api_url | jq ".assets[] | select(.name | contains(\"$2\") and contains(\"$3\") and (contains(\".sig\") | not)) | .browser_download_url")
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
        curl -L -o $artifact $(get_artifact_download_url ${artifacts[$artifact]})
    fi
done

chmod +x apkeep

# Download Azur Lane
download_azurlane () {
    if [ ! -f "com.YoStarJP.AzurLane" ]; then
        ./apkeep -a com.YoStarJP.AzurLane .
    fi
}

if [ ! -f "com.YoStarJP.AzurLane.apk" ]; then
    echo "Get Azur Lane apk"
    download_azurlane
    # Check if the downloaded file is an xapk
    if [[ $(file -b "com.YoStarJP.AzurLane" | cut -d' ' -f1) == "Zip" ]]; then
        echo "Extracting XAPK..."
        unzip -o com.YoStarJP.AzurLane -d AzurLane
        # Find the main apk file and copy it
        apk_file=$(find AzurLane -name 'com.YoStarJP.AzurLane.apk' -type f | head -n 1)
        if [ -n "$apk_file" ]; then
            cp "$apk_file" .
        else
            echo "Could not find main APK in XAPK."
            exit 1
        fi
    else
        # Assume it's a regular apk
        mv com.YoStarJP.AzurLane com.YoStarJP.AzurLane.apk
    fi
fi


# Download JMBQ
if [ ! -d "azurlane" ]; then
    echo "Downloading JMBQ"
    git clone https://github.com/feathers-l/azurlane
fi

echo "Decompile Azur Lane apk"
java -jar apktool.jar d -f -q com.YoStarJP.AzurLane.apk

echo "Copy JMBQ libs"
cp -r azurlane/. com.YoStarJP.AzurLane/lib/

echo "Patching Azur Lane with JMBQ"
# Find the line with the onCreate method definition
oncreate_line=$(grep -n -m 1 'onCreate' com.YoStarJP.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali)
# Extract just the text of the line, preserving indentation
oncreate=$(echo "$oncreate_line" | sed 's/^[0-9]*://')
smali_file="com.YoStarJP.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali"

# Apply patch using the logic from the Chinese version script
# This looks for the onCreate line followed by a .locals line and injects the loadLibrary call.
# Note: This assumes the line after onCreate is '.locals 2'. This might need adjustment if the smali code changes.
sed -ir "N; s#\($oncreate\n    .locals 2\)#\1\n\n    const-string v0, \"JMBQ\"\n\n    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V\n#" $smali_file


echo "Build Patched Azur Lane apk"
java -jar apktool.jar b -f -q com.YoStarJP.AzurLane -o build/com.YoStarJP.AzurLane.patched.apk

echo "Set Github Release version"
s=($(./apkeep -a com.YoStarJP.AzurLane -l))
echo "PERSEUS_VERSION=$(echo ${s[-1]})" >> $GITHUB_ENV

echo "Done."
