#!/bin/bash

# by ariakis, 2023
# a little hacky, but it works

function info {
    echo -e "\e[0;34m[-] $1\e[0m"
}
function success {
    echo -e "\e[0;32m[+] $1\e[0m"
}
function error {
    echo -e "\e[0;31m[!] $1\e[0m"
}

# consts

APKLAB_INSTALL_PATH="$HOME/.apklab"

# deps
if ! command -v yq &> /dev/null; then
    info "yq command not found, installing it..."
    sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
fi

if ! command -v jq &> /dev/null; then
    info "jq command not found, installing it..."
    sudo apt update
    sudo apt install -y jq
fi

if ! command -v baksmali &> /dev/null; then
    info "baksmali command not found..."
    info "TODO: auto-install baksmali"
    error "Exiting for now - install baksmali and try again..."
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    info "unzip command not found, installing it..."
    sudo apt update
    sudo apt install -y unzip
fi

if ! command -v java &> /dev/null; then
    info "java command not found..."
    error "Exiting for now - install java and try again..."
    exit 1
fi

# make sure we're a decompiled app directory

if ! [ -f apktool.yml ]; then
    error "apktool.yml file doesn't exist in the current directory. Switch to a decompiled app directory and try again."
    exit 1
fi

# begin!

# get the path to the latest apktool within apklab

APKTOOL_PATH="$APKLAB_INSTALL_PATH/$(cat $APKLAB_INSTALL_PATH/config.json | jq -r '.tools[] | select(.name | contains("apktool")).fileName')"
APKSIGNER_PATH="$APKLAB_INSTALL_PATH/$(cat $APKLAB_INSTALL_PATH/config.json | jq -r '.tools[] | select(.name | contains("uber-apk-signer")).fileName')"

# build
info "Building modified apk..."
if java -jar "$APKTOOL_PATH" b --use-aapt2 .; then
    success "Built modified apk :)"
else
    error "Failed to build modified apk - exiting..."
    exit 1
fi

# get apk name

APK_NAME="$(yq eval '.apkFileName' apktool.yml)"

# sign
info "Signing modified apk..."
if java -jar "$APKSIGNER_PATH" -a "dist/$APK_NAME" --allowResign --overwrite; then
    success "Signed modified apk :)"
else
    error "Failed to sign modified apk - exiting..."
    exit 1
fi

mv "dist/$APK_NAME" "dist/modded-$APK_NAME"
success "Modified apk moved to 'dist/modded-$APK_NAME'"

# switch back to orignal
info "Stashing changes to build original apk..."
if git stash; then
    success "Changes stashed"
else
    error "Failed to stash changes - exiting..."
    exit 1
fi

# build
info "Building original apk..."
if java -jar "$APKTOOL_PATH" b --use-aapt2 .; then
    success "Built original apk :)"
else
    error "Failed to build original apk - exiting..."
    exit 1
fi

# get apk name
APK_NAME="$(yq eval '.apkFileName' apktool.yml)"

# sign
info "Signing original apk..."
if java -jar "$APKSIGNER_PATH" -a "dist/$APK_NAME" --allowResign --overwrite; then
    success "Signed original apk :)"
else
    error "Failed to sign original apk - exiting..."
    exit 1
fi

# reload changes
info "Loading stashed changes..."
if git stash pop; then
    success "Stashed changes loaded"
else
    error "Failed to load stashed changes - exiting..."
    exit 1
fi

# compare 'em

# pull out dex from the og
info "(original) Extracting dex files..."
if unzip "dist/$APK_NAME" classes*.dex; then
    success "(original) Dex files extracted"
else
    error "(original) Failed to extract dex files - exiting..."
    exit 1
fi

# get hex files for the og
FILES="classes*.dex"
for file in $FILES; do 
    info "(original) Getting hex for $file..."
    baksmali du "$file" > "$file.hex"
    cat "$file.hex" | grep -v '000014:\|00001c:\|  checksum\|  signature\|  file_size\|  address_diff\|  addr_diff\|  insns_size\|  offset\| = class_data_item\| = code_item\|  data_size\|  map_off' | cut -c9- > "$file.hex.new"
    rm "$file"
    rm "$file.hex"
    mv "$file.hex.new" "$file.hex"
done

success "(original) Hex for all dex files obtained :)"

# pull out dex from the modded


info "(modded) Extracting dex files..."
if unzip "dist/modded-$APK_NAME" classes*.dex; then
    success "(modded) Dex files extracted"
else
    error "(modded) Failed to extract dex files - exiting..."
    exit 1
fi

FILES="classes*.dex"
for file in $FILES; do 
    echo "(modded) Getting hex for $file..."
    baksmali du "$file" > "modded-$file.hex"
    cat "modded-$file.hex" | grep -v '000014:\|00001c:\|  checksum\|  signature\|  file_size\|  address_diff\|  addr_diff\|  insns_size\|  offset\| = class_data_item\| = code_item\|  data_size\|  map_off' | cut -c9- > "modded-$file.hex.new"
    rm "$file"
    rm "modded-$file.hex"
    mv "modded-$file.hex.new" "modded-$file.hex"
done

success "(modded) Hex for all dex files obtained :)"

info "Creating patch files..."

# diff
FILES="classes*.dex.hex"
for file in $FILES; do 
    diff -u "$file" "modded-$file" > "changes-$file.patch"
    if [ ! -s "changes-$file.patch" ]; then
        info "modded-$file has no modifications"
        rm "changes-$file.patch"
    else
        success "modded-$file has modifications (saved to 'changes-$file.patch')"
    fi
    rm "$file"
    rm "modded-$file"
done

success "Done - the following patch files were created:"
ls *.patch
