#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    local err_message=${1:-""}
    local exit_die=${2:-"true"}
    (repo forall -c "git reset --hard; git clean -fdx") >/dev/null
    rm -f .repo/local_manifests/dyn-*.xml
    echo $err_message
    if [ "$exit_die" = "true" ]
    then
      exit 1
    fi
  fi
}

if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

if [ -z "$WORKSPACE" ]
then
  echo WORKSPACE not specified
  exit 1
fi

if [ ! -z "$GERRIT_BRANCH" ]
then
  export REPO_BRANCH=$GERRIT_BRANCH
fi

if [ -z "$REPO_BRANCH" ]
then
  echo REPO_BRANCH not specified
  exit 1
fi

if [ ! -z "$GERRIT_PROJECT" ]
then
  export RELEASE_TYPE=CM_EXPERIMENTAL
  export CM_EXTRAVERSION="gerrit-$GERRIT_CHANGE_NUMBER-$GERRIT_PATCHSET_NUMBER"
  export CLEAN="device"
  export GERRIT_XLATION_LINT=true

  vendor_name=$(echo $GERRIT_PROJECT | grep -Po '.*(?<=android_device_)[^_]*' | sed -e s#CyanogenMod/android_device_##g)
  device_name=$(echo $GERRIT_PROJECT | grep '.*android_device_[^_]*_' | sed -e s#.*android_device_[^_]*_##g | sed s#CyanogenMod/##g )

  if [[ "$GERRIT_PROJECT" == *kernel* ]]
  then
    vendor_name=$(echo $GERRIT_PROJECT | grep -Po '.*(?<=android_kernel_)[^_]*' | sed -e s#CyanogenMod/android_kernel_##g)
    device_name=$(echo $GERRIT_PROJECT | grep '.*android_kernel_[^_]*_' | sed -e s#.*android_kernel_[^_]*_##g | sed s#CyanogenMod/##g)
    if [[ "bcm21553-common" != $device_name ]]
    then
        device_name=msm7x27-common
    fi
  fi

  if [[ "$GERRIT_PROJECT" == *vendor_google* ]]
  then
    export MINI_GAPPS=true
  fi

  if [[ "$GERRIT_PROJECT" == "CyanogenMod/android" ]]
  then
    export CHERRYPICK_REV=$GERRIT_PATCHSET_REVISION
  fi

  # LDPI device (default)
  LUNCH=cm_$(DEVICE)-userdebug
  if [ ! -z $vendor_name ] && [ ! -z $device_name ]
  then
    # Workaround for failing translation checks in common device repositories
    LUNCH=$(echo cm_$device_name-userdebug@$vendor_name | sed -f $WORKSPACE/hudson/shared-repo.map)
  fi
  export LUNCH=$LUNCH
fi

if [ -z "$LUNCH" ]
then
  echo LUNCH not specified
  exit 1
fi

DEVICE=$(echo $LUNCH | sed s#cm_##g | sed s#-userdebug##g | sed s#-eng##g)

if [ -z "$CLEAN" ]
then
  echo CLEAN not specified
  exit 1
fi

if [ -z "$RELEASE_TYPE" ]
then
  echo RELEASE_TYPE not specified
  exit 1
fi

if [ -z "$SYNC_PROTO" ]
then
  SYNC_PROTO=git
fi

if [ -z "$SIGN_BUILD" ]
then
  SIGN_BUILD=false
fi

# colorization fix in Jenkins
export CL_RED="\"\033[31m\""
export CL_GRN="\"\033[32m\""
export CL_YLW="\"\033[33m\""
export CL_BLU="\"\033[34m\""
export CL_MAG="\"\033[35m\""
export CL_CYN="\"\033[36m\""
export CL_RST="\"\033[0m\""

cd $WORKSPACE
rm -rf archive
mkdir -p archive/delta
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export BUILD_WITH_COLORS=1

# create empty patches.txt if it doesn't exist
if [ ! -f $WORKSPACE/patches.txt ]; then
    touch patches.txt
fi

if [[ "$RELEASE_TYPE" == "CM_RELEASE" ]]
then
  export USE_CCACHE=0
else
  export USE_CCACHE=1
  export CCACHE_NLEVELS=4
fi

REPO=$(which repo)
if [ -z "$REPO" ]
then
  mkdir ~/bin
  export PATH=~/bin:$PATH
  curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
  chmod a+x ~/bin/repo
  source ~/.profile
  repo selfupdate
fi

if [ -z "$BUILD_USER_ID" ]
then
  export BUILD_USER_ID=$(whoami)
fi

git config --global user.name $BUILD_USER_ID@wimpnether
git config --global user.email $(whoami)@wimpnether.net

JENKINS_BUILD_DIR=$REPO_BRANCH

mkdir -p $JENKINS_BUILD_DIR
cd $JENKINS_BUILD_DIR

# always force a fresh repo init since we can build off different branches
# and the "default" upstream branch can get stuck on whatever was init first.
if [ -z "$CORE_BRANCH" ]
then
  CORE_BRANCH=$REPO_BRANCH
fi

if [ ! -z "$RELEASE_MANIFEST" ]
then
  MANIFEST="-m $RELEASE_MANIFEST"
else
  RELEASE_MANIFEST=""
  MANIFEST=""
fi

if [[ "$SYNC_PROTO" == "ssh" ]]
then
  repo init -u ssh://git@github.com/CyanogenMod/android.git -b $CORE_BRANCH $MANIFEST
else
  repo init -u $SYNC_PROTO://github.com/CyanogenMod/android.git -b $CORE_BRANCH $MANIFEST
fi
check_result "repo init failed."

if [ ! -z "$CHERRYPICK_REV" ]
then
  cd .repo/manifests
  sleep 20
  git fetch origin $GERRIT_REFSPEC
  git cherry-pick $CHERRYPICK_REV
  cd ../..
fi

if [ $USE_CCACHE -eq 1 ]
then
  # make sure ccache is in PATH
  export PATH="$PATH:/opt/local/bin/:$PWD/prebuilts/misc/$(uname|awk '{print tolower($0)}')-x86/ccache"
  #export CCACHE_DIR=/ccj/$JOB_NAME/$REPO_BRANCH/$DEVICE
  export CCACHE_DIR=$WORKSPACE/ccache/$DEVICE
  mkdir -p $CCACHE_DIR
fi

if [ -f ~/.jenkins_profile ]
then
  . ~/.jenkins_profile
fi

mkdir -p .repo/local_manifests
rm -f .repo/local_manifest.xml

cp $WORKSPACE/cm-hudson/target/local_manifests/*.xml .repo/local_manifests/

echo Core Manifest:
cat .repo/manifest.xml

echo Syncing...
# if sync fails, sync again, if sync fails then exit
repo sync -d -c -f -j8
check_result "repo sync failed.", false,

repo sync -d -c -f -j1
check_result "repo sync failed.", true

# SUCCESS
echo Sync complete.

# Apply gerrit changes from patches.txt. One change-id per line!
if [ -f $WORKSPACE/patches.txt ]; then
    while read line; do
        GERRIT_CHANGES+="$line "
    done < patches.txt

    if [[ ! -z ${GERRIT_CHANGES} && ! ${GERRIT_CHANGES} == " " ]]; then
        echo -e "${txtylw}Applying patches...${txtrst}"
        python $JENKINS_BUILD_DIR/build/tools/repopick.py $GERRIT_CHANGES --ignore-missing --start-branch auto --abandon-first
        echo -e "${txtgrn}Patches applied!${txtrst}"
    fi
fi

# Update-client
$WORKSPACE/cm-hudson/update_client.sh

#Vendor
$WORKSPACE/cm-hudson/cm-setup.sh

if [ -f .last_branch ]
then
  LAST_BRANCH=$(cat .last_branch)
else
  echo "Last build branch is unknown, assume clean build"
  LAST_BRANCH=$REPO_BRANCH-$CORE_BRANCH$RELEASE_MANIFEST
fi

if [ "$LAST_BRANCH" != "$REPO_BRANCH-$CORE_BRANCH$RELEASE_MANIFEST" ]
then
  echo "Branch has changed since the last build happened here. Forcing cleanup."
  CLEAN="full"
fi

. build/envsetup.sh
lunch $LUNCH
check_result "lunch failed."

# save manifest used for build (saving revisions as current HEAD)

# include only the auto-generated locals
TEMPSTASH=$(mktemp -d)
mv .repo/local_manifests/* $TEMPSTASH
mv $TEMPSTASH/roomservice.xml .repo/local_manifests/

# save it
repo manifest -o $WORKSPACE/archive/manifest.xml -r

# restore all local manifests
mv $TEMPSTASH/* .repo/local_manifests/ 2>/dev/null
rm -rf $TEMPSTASH

rm -f $OUT/cm-*.zip*

UNAME=$(uname)

if [ "$RELEASE_TYPE" = "CM_NIGHTLY" ]
then
  export CM_NIGHTLY=true
elif [ "$RELEASE_TYPE" = "CM_EXPERIMENTAL" ]
then
  export CM_EXPERIMENTAL=true
elif [ "$RELEASE_TYPE" = "CM_RELEASE" ]
then
  export CM_RELEASE=true
fi

if [ ! -z "$CM_EXTRAVERSION" ]
then
  export CM_EXPERIMENTAL=true
fi

if [ ! -z "$GERRIT_CHANGE_NUMBER" ]
then
  export GERRIT_CHANGES=$GERRIT_CHANGE_NUMBER
fi

if [ ! -z "$GERRIT_CHANGES" ]
then
  export CM_EXPERIMENTAL=true
  IS_HTTP=$(echo $GERRIT_CHANGES | grep http)
  if [ -z "$IS_HTTP" ]
  then
    python $WORKSPACE/cm-hudson/repopick.py $GERRIT_CHANGES
    check_result "gerrit picks failed."
  else
    python $WORKSPACE/cm-hudson/repopick.py $(curl $GERRIT_CHANGES)
    check_result "gerrit picks failed."
  fi
  if [ ! -z "$GERRIT_XLATION_LINT" ]
  then
    python $WORKSPACE/cm-hudson/xlationlint.py $GERRIT_CHANGES
    check_result "basic XML lint failed."
  fi
fi

if [ $USE_CCACHE -eq 1 ]
then
  if [ ! "$(ccache -s|grep -E 'max cache size'|awk '{print $4}')" = "9.0" ]
  then
    ccache -M 8G
  fi
  echo "============================================"
  ccache -s
  echo "============================================"
fi


rm -f $WORKSPACE/changecount
WORKSPACE=$WORKSPACE LUNCH=$LUNCH bash $WORKSPACE/cm-hudson/changes/buildlog.sh 2>&1
if [ -f $WORKSPACE/changecount ]
then
  CHANGE_COUNT=$(cat $WORKSPACE/changecount)
  rm -f $WORKSPACE/changecount
  if [ $CHANGE_COUNT -eq "0" ]
  then
    echo "Zero changes since last build, aborting"
    exit 1
  fi
fi

LAST_CLEAN=0
if [ -f .clean ]
then
  LAST_CLEAN=$(date -r .clean +%s)
fi
TIME_SINCE_LAST_CLEAN=$(expr $(date +%s) - $LAST_CLEAN)
# convert this to hours
TIME_SINCE_LAST_CLEAN=$(expr $TIME_SINCE_LAST_CLEAN / 60 / 60)
if [ $TIME_SINCE_LAST_CLEAN -gt "72" -o $CLEAN = "true" -o $CLEAN = "full" ]
then
  echo "Cleaning $CLEAN!"
  touch .clean
  make clobber
elif [ $CLEAN = "device" ]
then
  echo "Cleaning $OUT!"
  rm -fr $OUT
else
  echo "Skipping clean: $TIME_SINCE_LAST_CLEAN hours since last clean."
fi

echo "$REPO_BRANCH-$CORE_BRANCH$RELEASE_MANIFEST" > .last_branch

# envsetup.sh:mka = schedtool -B -n 1 -e ionice -n 1 make -j$(cat /proc/cpuinfo | grep "^processor" | wc -l) "$@"
# Don't add -jXX. mka adds it automatically...
case "$JOB_NAME" in
    cm-recovery)
        source $WORKSPACE/cm-hudson/update_zip.sh recovery
    ;;
    cm-kernel)
        source $WORKSPACE/cm-hudson/update_zip.sh kernel
    ;;

    blackhawk-kernel)
        source $WORKSPACE/cm-hudson/update_zip.sh blackhawk-kernel
    ;;

    blackhawk-recovery)
        source $WORKSPACE/cm-hudson/update_zip.sh blackhawk-recovery
    ;;

    *)
        time mka bacon #checkapi
    ;;

esac

check_result "Build failed."

if [ $USE_CCACHE -eq 1 ]
then
  echo "============================================"
  ccache -V
  echo "============================================"
  ccache -s
  echo "============================================"
fi

if [ "$SIGN_BUILD" = "true" ]
then
  MODVERSION=$(cat $OUT/system/build.prop | grep ro.cm.version | cut -d = -f 2)
  SDKVERSION=$(cat $OUT/system/build.prop | grep ro.build.version.sdk | cut -d = -f 2)
  if [ ! -z "$MODVERSION" -a -f $OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-$BUILD_NUMBER.zip ]
  then
    misc_info_txt=$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-$BUILD_NUMBER/META/misc_info.txt
    function get_meta_val {
        echo $(cat $misc_info_txt | grep ${1} | cut -d = -f 2)
    }
    minigzip=$(get_meta_val "minigzip")
    if [ ! -z "$minigzip" ]
    then
        export MINIGZIP="$minigzip"
    fi

#Only test
last_dir=$(pwd)
echo -e "$last_dir"

    BIN_JAVA=java
    BIN_MINSIGNAPK=$ANDROID_HOST_OUT/opendelta/minsignapk.jar
    BIN_XDELTA=$ANDROID_HOST_OUT/opendelta/xdelta3
    BIN_ZIPADJUST=$ANDROID_HOST_OUT/opendelta/zipadjust
    # Sign Keys
    KEY_X509=$WORKSPACE/$JENKINS_BUILD_DIR/build/target/product/security/platform.x509.pem
    KEY_PK8=$WORKSPACE/$JENKINS_BUILD_DIR/build/target/product/security/platform.pk8

    #Tools
    mkdir -p ${ANDROID_HOST_OUT}/opendelta
    check_result "unable make ${ANDROID_HOST_OUT}/opendelta dir"

    if [ ! -e ${ANDROID_HOST_OUT}/linux-x86/bin/unpackbootimg ]; then
        mka unpackbootimg
    fi
    if [ ! -e ${ANDROID_PRODUCT_OUT}/obj/EXECUTABLES/updater_intermediates/updater ]; then
        mka updater
    fi

    if [ ! -e ${ANDROID_HOST_OUT}/opendelta/minsignapk.jar ]; then
        echo "Get minsignapk"
        mkdir $WORKSPACE/temp
        cd $WORKSPACE/temp
        svn checkout https://github.com/omnirom/android_packages_apps_OpenDelta/trunk/server files
        check_result "Get minsignapk failed"
        cd files
        cp minsignapk.jar $ANDROID_HOST_OUT/opendelta/minsignapk.jar
        cp MinSignAPK.java $ANDROID_HOST_OUT/opendelta/MinSignAPK.java
        echo "Done"
    fi

    if [ ! -e ${ANDROID_HOST_OUT}/opendelta/xdelta3 ]; then
        echo "Building xdelta3"
        mkdir $WORKSPACE/temp
        cd $WORKSPACE/temp
        svn checkout https://github.com/omnirom/android_packages_apps_OpenDelta/trunk/jni install
        cd install/xdelta3-3.0.7
        chmod +x configure
        ./configure
        make
        check_result "xdelta3 build failed"
        cp xdelta3 ${ANDROID_HOST_OUT}/opendelta/xdelta3
        echo "Done"
    fi

    if [ ! -e ${ANDROID_HOST_OUT}/opendelta/zipadjust ]; then
        echo "Building zipadjust"
        cd $WORKSPACE/temp/install
        gcc -o zipadjust zipadjust.c zipadjust_run.c -lz
        check_result "zipadjust build failed"
        cp zipadjust ${ANDROID_HOST_OUT}/opendelta/zipadjust
        echo "Done"
    fi

    # Clean temp
    cd $last_dir
    rm -rf $WORKSPACE/temp

    #Ota Dirs
    DOWNLOAD_WIMPNETHER_NET_DEVICE=~/otabuilds/full_builds/$DEVICE
    DOWNLOAD_WIMPNETHER_NET_DELTAS=~/otabuilds/nightlies/$DEVICE

    mkdir -p $DOWNLOAD_WIMPNETHER_NET_DEVICE
    mkdir -p $DOWNLOAD_WIMPNETHER_NET_DELTAS

    if [ ! -e $WORKSPACE/archive/cm-*.zip ]
        then
          echo -e "Moving build to archive"
          cp $OUT/cm-*.zip $WORKSPACE/archive/
    fi

    if [ ! -e $DOWNLOAD_WIMPNETHER_NET_DEVICE/cm-*.zip ]
        then
          echo -e "Last zip not found"
          echo -e "Copying latest build to last zip"
          cp $WORKSPACE/archive/cm-*.zip $DOWNLOAD_WIMPNETHER_NET_DEVICE/
          echo -e "Done"
          exit 1
    fi

    CM_ZIP=
    for f in $(ls $WORKSPACE/archive/cm-*.zip)
    do
      CM_ZIP=$(basename $f)
    done
    if [ -f $DOWNLOAD_WIMPNETHER_NET_DEVICE/$CM_ZIP ]
    then
      echo "File $CM_ZIP exists on download.wimpnether.net"
      echo "Only 1 build is allowed for 1 device on 1 day"
      make clobber >/dev/null
      rm -fr $OUT
      exit 1
    fi

# ------ PROCESS ------

getFileName() {
	echo ${1##*/}
    }

getFileNameNoExt() {
	echo ${1%.*}
}

getFileMD5() {
	TEMP=$(md5sum -b $1)
	for T in $TEMP; do echo $T; break; done
}

getFileSize() {
	echo $(stat --print "%s" $1)
}

nextPowerOf2() {
    local v=$1;
    ((v -= 1));
    ((v |= $v >> 1));
    ((v |= $v >> 2));
    ((v |= $v >> 4));
    ((v |= $v >> 8));
    ((v |= $v >> 16));
    ((v += 1));
    echo $v;
}

    CURRENT=$(getFileName $(ls -1 $WORKSPACE/archive/cm-*.zip))
    LAST=$(getFileName $(ls -1 $DOWNLOAD_WIMPNETHER_NET_DEVICE/cm-*.zip))
    LAST_BASE=$(getFileNameNoExt $LAST)

    mkdir $WORKSPACE/work
    mkdir $WORKSPACE/out

    $BIN_ZIPADJUST --decompress $CURRENT $WORKSPACE/work/current.zip
    check_result "decompress current failed"
    $BIN_ZIPADJUST --decompress $LAST $WORKSPACE/work/last.zip
    check_result "decompress last failed"
    $BIN_JAVA -Xmx1024m -jar $BIN_MINSIGNAPK $KEY_X509 $KEY_PK8 $WORKSPACE/work/current.zip work/current_signed.zip
    $BIN_JAVA -Xmx1024m -jar $BIN_MINSIGNAPK $KEY_X509 $KEY_PK8 $WORKSPACE/work/last.zip work/last_signed.zip
    SRC_BUFF=$(nextPowerOf2 $(getFileSize $WORKSPACE/work/current.zip));
    $BIN_XDELTA -B ${SRC_BUFF} -9evfS none -s $WORKSPACE/work/last.zip $WORKSPACE/work/current.zip $WORKSPACE/out/$LAST_BASE.update
    SRC_BUFF=$(nextPowerOf2 $(getFileSize work/current_signed.zip));
    $BIN_XDELTA -B ${SRC_BUFF} -9evfS none -s $WORKSPACE/work/current.zip $WORKSPACE/work/current_signed.zip $WORKSPACE/out/$LAST_BASE.sign

    MD5_CURRENT=$(getFileMD5 $CURRENT)
    MD5_CURRENT_STORE=$(getFileMD5 $WORKSPACE/work/current.zip)
    MD5_CURRENT_STORE_SIGNED=$(getFileMD5 $WORKSPACE/work/current_signed.zip)
    MD5_LAST=$(getFileMD5 $LAST)
    MD5_LAST_STORE=$(getFileMD5 $WORKSPACE/work/last.zip)
    MD5_LAST_STORE_SIGNED=$(getFileMD5 $WORKSPACE/work/last_signed.zip)
    MD5_UPDATE=$(getFileMD5 $WORKSPACE/out/$LAST_BASE.update)
    MD5_SIGN=$(getFileMD5 $WORKSPACE/out/$LAST_BASE.sign)

    SIZE_CURRENT=$(getFileSize $CURRENT)
    SIZE_CURRENT_STORE=$(getFileSize $WORKSPACE/work/current.zip)
    SIZE_CURRENT_STORE_SIGNED=$(getFileSize $WORKSPACE/work/current_signed.zip)
    SIZE_LAST=$(getFileSize $LAST)
    SIZE_LAST_STORE=$(getFileSize $WORKSPACE/work/last.zip)
    SIZE_LAST_STORE_SIGNED=$(getFileSize $WORKSPACE/work/last_signed.zip)
    SIZE_UPDATE=$(getFileSize $WORKSPACE/out/$LAST_BASE.update)
    SIZE_SIGN=$(getFileSize $WORKSPACE/out/$LAST_BASE.sign)

    DELTA=$WORKSPACE/out/$LAST_BASE.delta

    echo "{" > $DELTA
    echo "  \"version\": 1," >> $DELTA
    echo "  \"in\": {" >> $DELTA
    echo "      \"name\": \"$FILE_LAST\"," >> $DELTA
    echo "      \"size_store\": $SIZE_LAST_STORE," >> $DELTA
    echo "      \"size_store_signed\": $SIZE_LAST_STORE_SIGNED," >> $DELTA
    echo "      \"size_official\": $SIZE_LAST," >> $DELTA
    echo "      \"md5_store\": \"$MD5_LAST_STORE\"," >> $DELTA
    echo "      \"md5_store_signed\": \"$MD5_LAST_STORE_SIGNED\"," >> $DELTA
    echo "      \"md5_official\": \"$MD5_LAST\"" >> $DELTA
    echo "  }," >> $DELTA
    echo "  \"update\": {" >> $DELTA
    echo "      \"name\": \"$FILE_LAST_BASE.update\"," >> $DELTA
    echo "      \"size\": $SIZE_UPDATE," >> $DELTA
    echo "      \"size_applied\": $SIZE_CURRENT_STORE," >> $DELTA
    echo "      \"md5\": \"$MD5_UPDATE\"," >> $DELTA
    echo "      \"md5_applied\": \"$MD5_CURRENT_STORE\"" >> $DELTA
    echo "  }," >> $DELTA
    echo "  \"signature\": {" >> $DELTA
    echo "      \"name\": \"$FILE_LAST_BASE.sign\"," >> $DELTA
    echo "      \"size\": $SIZE_SIGN," >> $DELTA
    echo "      \"size_applied\": $SIZE_CURRENT_STORE_SIGNED," >> $DELTA
    echo "      \"md5\": \"$MD5_SIGN\"," >> $DELTA
    echo "      \"md5_applied\": \"$MD5_CURRENT_STORE_SIGNED\"" >> $DELTA
    echo "  }," >> $DELTA
    echo "  \"out\": {" >> $DELTA
    echo "      \"name\": \"$FILE_CURRENT\"," >> $DELTA
    echo "      \"size_store\": $SIZE_CURRENT_STORE," >> $DELTA
    echo "      \"size_store_signed\": $SIZE_CURRENT_STORE_SIGNED," >> $DELTA
    echo "      \"size_official\": $SIZE_CURRENT," >> $DELTA
    echo "      \"md5_store\": \"$MD5_CURRENT_STORE\"," >> $DELTA
    echo "      \"md5_store_signed\": \"$MD5_CURRENT_STORE_SIGNED\"," >> $DELTA
    echo "      \"md5_official\": \"$MD5_CURRENT\"" >> $DELTA
    echo "  }" >> $DELTA
    echo "}" >> $DELTA

    cp $WORKSPACE/out/* $WORKSPACE/archive/delta/.

    rm -rf $WORKSPACE/work
    rm -rf $WORKSPACE/out

    if [ "$RELEASE_TYPE" = "CM_RELEASE" ]
    then
      DOWNLOAD_WIMPNETHER_NET_DEVICE="$DOWNLOAD_WIMPNETHER_NET_DEVICE"
    else
      # Remove older nightlies and deltas
      find $DOWNLOAD_WIMPNETHER_NET_DEVICE -name "cm*NIGHTLY*" -type f -mtime +63 -delete
      find $DOWNLOAD_WIMPNETHER_NET_DELTAS -name "incremental-*" -type f -mtime +70 -delete
    fi

    # changelog
    cp $WORKSPACE/archive/CHANGES.txt $DOWNLOAD_WIMPNETHER_NET_DEVICE/cm-$MODVERSION.txt

    for f in $(ls $WORKSPACE/archive/delta/$LAST_BASE.delta*)
    do
      cp $f $DOWNLOAD_WIMPNETHER_NET_DELTAS
    done

    # /recovery
    if [ "$EXPORT_RECOVERY" = "true" -a -f $OUT/recovery.img ]
    then
      cp $OUT/recovery.img $DOWNLOAD_WIMPNETHER_NET_DEVICE/recovery/recovery-$DEVICE.img
    fi

  else
    echo "Unable to find target files to sign"
    exit 1
  fi
else
  # /archive
  for f in $(ls $OUT/cm-*.zip*)
  do
    ln $f $WORKSPACE/archive/$(basename $f)
  done
fi

if [ -f $OUT/utilties/update.zip ]
then
  cp $OUT/utilties/update.zip $WORKSPACE/archive/recovery.zip
fi
if [ -f $OUT/recovery.img ]
then
  cp $OUT/recovery.img $WORKSPACE/archive

fi

# archive the build.prop as well
ZIP=$(ls $WORKSPACE/archive/cm-*.zip)
unzip -p $ZIP system/build.prop > $WORKSPACE/archive/build.prop

# CORE: save manifest used for build (saving revisions as current HEAD)
rm -f .repo/local_manifests/roomservice.xml

# Stash away other possible manifests
TEMPSTASH=$(mktemp -d)
mv .repo/local_manifests $TEMPSTASH

repo manifest -o $WORKSPACE/archive/core.xml -r

mv $TEMPSTASH/local_manifests .repo
rmdir $TEMPSTASH

# chmod the files in case UMASK blocks permissions
chmod -R ugo+r $WORKSPACE/archive

# copy to workspace
rm -fr $OLDWORKSPACE/archive
mkdir -p $OLDWORKSPACE/archive
cp -a $WORKSPACE/archive/. $OLDWORKSPACE/archive/.

