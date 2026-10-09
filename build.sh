#!/bin/bash
# Original script by TIMISONG-dev
# Make sure you have zstd installed.

export DEVICE="munch"
#export TGTOKEN=bot_token
#export CHAT_ID=chat_id

start_time=$(date +%s)

MAINPATH=/home/runner/work/kernel_xiaomi_sm8250/kernel_xiaomi_sm8250

KERNEL_DIR=$MAINPATH
KERNEL_PATH=$KERNEL_DIR/kernel_xiaomi_sm8250

CLANG_DIR=$KERNEL_DIR/clang24

check_and_wget() {
    local dir=$1
    local repo=$2

    if [ ! -d "$dir" ]; then
        echo "Directory $dir doesnt exist. Cloning $repo."
        mkdir $dir
        cd $dir
        wget $repo
        tar --zstd -xvf neutron-clang-06092026.tar.zst
        rm -rf neutron-clang-06092026.tar.zst
        cd ../kernel_xiaomi_sm8250
    fi
}

check_and_wget $CLANG_DIR https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/06092026/neutron-clang-06092026.tar.zst

PATH=$CLANG_DIR/bin:$PATH
export PATH
export ARCH=arm64

AK3_DIR="$KERNEL_DIR/main"

if [ ! -d "$AK3_DIR" ]; then
    mkdir -p "$AK3_DIR"
    
    if [ ! -d "$AK3_DIR/Anykernel" ]; then
        git clone https://github.com/nunkki/Anykernel3-Munch.git "$AK3_DIR/Anykernel"
        
        mv "$AK3_DIR/Anykernel/"* "$AK3_DIR/"
        
        rm -rf "$AK3_DIR/Anykernel"
    fi
else
    if [ -d "$AK3_DIR/.git" ]; then
        rm -rf "$AK3_DIR/.git"
    fi
fi

export IMGPATH="$AK3_DIR/Image"
export DTBPATH="$AK3_DIR/dtb"
export DTBOPATH="$AK3_DIR/dtbo.img"
export KBUILD_BUILD_USER="action"
export KBUILD_BUILD_HOST="github.com"

MORPHITE_BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

output_dir=out

make O="$output_dir" \
            vendor/${DEVICE}_defconfig

    make -j $(nproc) \
                O="$output_dir" \
                CC="ccache clang" \
                HOSTCC=gcc \
                LD=ld.lld \
                AS=llvm-as \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
                LLVM=1 \
                LLVM_IAS=1 \
                V=$VERBOSE 2>&1 | tee build.log
                

find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
find $DTS -name 'Image' -exec cat {} + > $IMGPATH
find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH

end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

cd "$KERNEL_PATH"

if grep -q -E "Error 2" build.log; then
    cd "$KERNEL_PATH"
    echo "Error: Compilation failed"

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
    -d chat_id="$CHAT_ID" \
    -d text="Compilation error!"

    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=$CHAT_ID" \
    -F document=@"./build.log"
else
    echo "Total execution time: $elapsed_time second"
    cd "$AK3_DIR"
    7z a -mx9 Morphite+-AOSP-$DEVICE-$MORPHITE_BUILD_DATE.zip * -x!*.zip

    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
    -d chat_id="$CHAT_ID" \
    -d text="Compilation completed successfully! Execution time: $elapsed_time seconds"

    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=$CHAT_ID" \
    -F document=@"./Morphite+-AOSP-$DEVICE-$MORPHITE_BUILD_DATE.zip" \
    -F caption="Morphite+ | branch: ${BRANCH}"
fi
