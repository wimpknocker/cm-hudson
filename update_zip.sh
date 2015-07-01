#!/bin/bash

EXTRABUILD=$1
#modver=""

DOWNLOAD_WIMPNETHER_NET_DEVICE_KERNEL=~/otabuilds/_builds/$DEVICE/kernel
DOWNLOAD_WIMPNETHER_NET_DEVICE_RECOVERY=~/otabuilds/_builds/$DEVICE/recovery
DOWNLOAD_WIMPNETHER_NET_DEVICE_BLACKHAWK=~/otabuilds/_builds/$DEVICE/blackhawk

mkdir -p DOWNLOAD_WIMPNETHER_NET_DEVICE_KERNEL
mkdir -p DOWNLOAD_WIMPNETHER_NET_DEVICE_RECOVERY
mkdir -p DOWNLOAD_WIMPNETHER_NET_DEVICE_BLACKHAWK

# create kernel zip
create_kernel_zip()
{
    echo -e "${txtgrn}Creating kernel zip...${txtrst}"
    if [ -e ${ANDROID_PRODUCT_OUT}/boot.img ]; then
        echo -e "${txtgrn}Bootimage found...${txtrst}"
        if [ -e $WORKSPACE/cm-hudson/target/updater-scripts/$DEVICE/kernel_updater-script ]; then

            echo -e "${txtylw}Package KERNELUPDATE:${txtrst} out/target/product/${CMD}/kernel-${REPO_BRANCH}-$(date +%Y%m%d)-${DEVICE}-signed.zip"
            cd ${ANDROID_PRODUCT_OUT}

            rm -rf kernel_zip
            rm kernel-${REPO_BRANCH}-*

            mkdir -p kernel_zip/META-INF/com/google/android

            echo "Copying boot.img..."
              cp boot.img kernel_zip/

            echo "Copying update-binary..."
              cp obj/EXECUTABLES/updater_intermediates/updater kernel_zip/META-INF/com/google/android/update-binary

            echo "Copying updater-script..."
              cat $WORKSPACE/cm-hudson/target/updater-scripts/$DEVICE/kernel_updater-script > kernel_zip/META-INF/com/google/android/updater-script

            echo "Zipping package..."
              cd kernel_zip
              zip -qr ../kernel-${REPO_BRANCH}-$(date +%Y%m%d)-${DEVICE}.zip ./
              cd ${ANDROID_PRODUCT_OUT}

            echo "Signing package..."
              java -jar ${ANDROID_HOST_OUT}/framework/signapk.jar $JENKINS_BUILD_DIR/build/target/product/security/testkey.x509.pem $JENKINS_BUILD_DIR/build/target/product/security/testkey.pk8 kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}.zip kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip
              rm kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}.zip

            echo -e "${txtgrn}Package complete:${txtrst} out/target/product/${CMD}/kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip"
              md5sum kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip > kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip.md5sum
              cp kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip $DOWNLOAD_WIMPNETHER_NET_DEVICE_KERNEL
              cp kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip.md5sum $DOWNLOAD_WIMPNETHER_NET_DEVICE_KERNEL
              cd $JENKINS_BUILD_DIR
        else
            echo -e "${txtred}No instructions to create out/target/product/${CMD}/kernel-cm-${CM_VERSION}-$(date +%Y%m%d)-${DEVICE}-signed.zip... skipping."
            echo -e "\r\n ${txtrst}"
        fi
    else
        echo -e "${txtred}Bootimage not found... skipping."
        echo -e "\r\n ${txtrst}"
    fi
}

create_blackhawk_kernel_zip()
{
   echo -e "${txtgrn}Creating blackhawk kernel zip...${txtrst}"
    if [ -e ${ANDROID_PRODUCT_OUT}/boot.img ]; then
        echo -e "${txtgrn}Bootimage found...${txtrst}"
        if [ -e $WORKSPACE/cm-hudson/target/updater-scripts/$DEVICE/blackhawk_kernel_updater-script ]; then

            echo -e "${txtylw}Package BLACKHAWKUPDATE:${txtrst} out/target/product/${CMD}/blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip"
            cd ${ANDROID_PRODUCT_OUT}

            rm -rf kernel_zip
            rm kernel-${REPO_BRANCH}-*
            rm blackhawk-next-kernel*
            mkdir -p kernel_zip/META-INF/com/google/android

            echo "Unpack boot.img.."
              unpackbootimg -i boot.img  -o boot_img
              cd boot_img
              rm *ramdisk*

            echo "Building blackhawk"
              git clone https://github.com/wimpknocker/android_dualboot.git -b ${DEVICE} ramdisk
              cd ramdisk/ramdisk
              find . | cpio -o -H newc | gzip > ../../blackhawk-ramdisk.cpio.gz
              cd ../..
              mkbootimg --kernel *-kernel --ramdisk blackhawk-ramdisk.cpio.gz --cmdline *-cmdline --base *-base --pagesize *-pagesize -o ../kernel_zip/boot.img

            echo "Copying updater-script..."
              cat $WORKSPACE/cm-hudson/target/updater-scripts/${DEVICE}/blackhawk_kernel_updater-script > kernel_zip/META-INF/com/google/android/updater-script

            echo "Zipping package..."
              cd kernel_zip
              zip -qr ../blackhawk-next-kernel-${modver}-${DEVICE}.zip ./
              cd ${ANDROID_PRODUCT_OUT}

            echo "Signing package..."
              java -jar ${ANDROID_HOST_OUT}/framework/signapk.jar $JENKINS_BUILD_DIR/build/target/product/security/testkey.x509.pem $JENKINS_BUILD_DIR/build/target/product/security/testkey.pk8 blackhawk-next-kernel-${modver}-${DEVICE}.zip blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip
              rm blackhawk-next-kernel-${modver}-${DEVICE}.zip

            echo -e "${txtgrn}Package complete:${txtrst} out/target/product/${CMD}/blackhawk-next-kernel-${modver}-${CMD}-signed.zip"
              md5sum blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip > blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip.md5sum
              cp blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip $DOWNLOAD_WIMPNETHER_NET_DEVICE_BLACKHAWK
              cp blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip.md5sum $DOWNLOAD_WIMPNETHER_NET_DEVICE_BLACKHAWK
              cd $JENKINS_BUILD_DIR
        else
            echo -e "${txtred}No instructions to create out/target/product/${CMD}/blackhawk-next-kernel-${modver}-${DEVICE}-signed.zip... skipping."
            echo -e "\r\n ${txtrst}"
        fi
    else
        echo -e "${txtred}Bootimage not found... skipping."
        echo -e "\r\n ${txtrst}"
    fi
}

create_blackhawk_recovery_zip()
{
   echo -e "${txtgrn}Creating blackhawk recovery zip...${txtrst}"
    if [ -e ${ANDROID_PRODUCT_OUT}/blackhawk-recovery.img ]; then
        echo -e "${txtgrn}recoveryimage found...${txtrst}"
        if [ -e $WORKSPACE/cm-hudson/target/updater-scripts/${DEVICE}/blackhawk_recovery_updater-script ]; then

            echo -e "${txtylw}Package BLACKHAWKUPDATE:${txtrst} out/target/product/${CMD}/PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip"
              cd ${ANDROID_PRODUCT_OUT}
              rm -rf recovery_zip
              rm PhilZ-Touch-Recovery*

            mkdir -p recovery_zip/META-INF/com/google/android

            echo "Copying recovery image..."
              cp blackhawk-recovery.img recovery_zip/blackhawk-recovery.img

            echo "Copying updater-script..."
              cat $WORKSPACE/cm-hudson/target/updater-scripts/$DEVICE/blackhawk_recovery_updater-script > recovery_zip/META-INF/com/google/android/updater-script

            echo "Zipping package..."
              cd recovery_zip
              zip -qr ../PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip ./
              cd ${ANDROID_PRODUCT_OUT}
              md5sum PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip > PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip.md5sum
              cp PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip $DOWNLOAD_WIMPNETHER_NET_DEVICE_BLACKHAWK
              cp PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip.md5sum $DOWNLOAD_WIMPNETHER_NET_DEVICE_BLACKHAWK
              cd $JENKINS_BUILD_DIR

        else
            echo -e "${txtred}No instructions to create out/target/product/${CMD}/PhilZ-Touch-Recovery_${PHILZ_BUILD}-blackhawk-${DEVICE}.zip... skipping."
            echo -e "\r\n ${txtrst}"
        fi
    else
        echo -e "${txtred}recoveryimage not found... skipping."
        echo -e "\r\n ${txtrst}"
    fi
}

case "$EXTRABUILD" in
    kernel)
        echo -e "${txtgrn}Rebuilding bootimage...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/kernel_zip
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/boot.img
        rm -rf ${ANDROID_PRODUCT_OUT}/root
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*
        rm -rf ${ANDROID_PRODUCT_OUT}/combined*

        time mka bootimage
        if [ ! -e ${ANDROID_PRODUCT_OUT}/obj/EXECUTABLES/updater_intermediates/updater ]; then
            mka updater
        fi
        if [ ! -e ${ANDROID_HOST_OUT}/framework/signapk.jar ]; then
            mka signapk
        fi
        create_kernel_zip
        ;;

    blackhawk-kernel)
        echo -e "${txtgrn}Rebuilding bootimage with blackhawk support...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/kernel_zip
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/boot.img
        rm ${ANDROID_PRODUCT_OUT}/recovery.img
        rm -rf ${ANDROID_PRODUCT_OUT}/root
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*
        rm -rf ${ANDROID_PRODUCT_OUT}/combined*

        time mka bootimage
        if [ ! -e ${ANDROID_HOST_OUT}/linux-x86/bin/unpackbootimg ]; then
            mka unpackbootimg
        fi
        if [ ! -e ${ANDROID_PRODUCT_OUT}/obj/EXECUTABLES/updater_intermediates/updater ]; then
            mka updater
        fi
        if [ ! -e ${ANDROID_HOST_OUT}/framework/signapk.jar ]; then
            mka signapk
        fi

        create_blackhawk_kernel_zip
        ;;

    recovery)
        echo -e "${txtgrn}Rebuilding recoveryimage...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/recovery.img
        rm ${ANDROID_PRODUCT_OUT}/recovery
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*

        time mka ${ANDROID_PRODUCT_OUT}/recovery.img
        cp recovery.img $DOWNLOAD_WIMPNETHER_NET_DEVICE_RECOVERY/recovery-CWM-${RECOVERY_VERSION}-$(date +%Y%m%d)-${DEVICE}.img
        ;;

    blackhawk-recovery)
        echo -e "${txtgrn}Rebuilding recoveryimage with blackhawk support...${txtrst}"

        rm -rf ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ
        rm ${ANDROID_PRODUCT_OUT}/kernel
        rm ${ANDROID_PRODUCT_OUT}/recovery.img
        rm ${ANDROID_PRODUCT_OUT}/recovery
        rm -rf ${ANDROID_PRODUCT_OUT}/ramdisk*

        export RECOVERY_VARIANT=philz

        mka recoveryimage
        mv ${ANDROID_PRODUCT_OUT}/recovery.img ${ANDROID_PRODUCT_OUT}/blackhawk-recovery.img
        if [ ! -e ${ANDROID_PRODUCT_OUT}/obj/EXECUTABLES/updater_intermediates/updater ]; then
            mka updater
        fi

        create_blackhawk_recovery_zip
        ;;

esac

exit 0
