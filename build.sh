#!/usr/bin/env bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    local err_message=${1:-""}
    local exit_die=${2:-"true"}
    local rm_roomservice=${3:-"true"}
    (repo forall -c "git reset --hard; git clean -fdx") >/dev/null
    rm -f .repo/local_manifests/dyn-*.xml
    if [ "$rm_roomservice" = "true" ]
    then
      rm -f .repo/local_manifests/roomservice.xml
    fi
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
  export VIRUS_SCAN=true

  vendor_name=$(echo $GERRIT_PROJECT | grep -Po '.*(?<=android_device_)[^_]*' | sed -e s#androidarmv6/android_device_##g)
  device_name=$(echo $GERRIT_PROJECT | grep '.*android_device_[^_]*_' | sed -e s#.*android_device_[^_]*_##g | sed s#androidarmv6/##g )

  if [[ "$GERRIT_PROJECT" == *kernel* ]]
  then
    vendor_name=$(echo $GERRIT_PROJECT | grep -Po '.*(?<=android_kernel_)[^_]*' | sed -e s#androidarmv6/android_kernel_##g)
    device_name=$(echo $GERRIT_PROJECT | grep '.*android_kernel_[^_]*_' | sed -e s#.*android_kernel_[^_]*_##g | sed s#androidarmv6/##g)
    if [[ "bcm21553-common" != $device_name ]]
    then
        device_name=msm7x27-common
    fi
  fi

  if [[ "$GERRIT_PROJECT" == *vendor_google* ]]
  then
    export MINI_GAPPS=true
  fi

  if [[ "$GERRIT_PROJECT" == "androidarmv6/android" ]]
  then
    export CHERRYPICK_REV=$GERRIT_PATCHSET_REVISION
  fi

  # LDPI device (default)
  LUNCH=cm_totoro-userdebug
  if [ ! -z $vendor_name ] && [ ! -z $device_name ]
  then
    # Workaround for failing translation checks in common device repositories
    LUNCH=$(echo cm_$device_name-userdebug@$vendor_name | sed -f $WORKSPACE/hudson/androidarmv6-shared-repo.map)
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

if [ -z "$FORCE_FULL_OTA" ]
then
  FORCE_FULL_OTA=false
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
mkdir -p archive
export BUILD_NO=$BUILD_NUMBER
unset BUILD_NUMBER

export PATH=~/bin:$PATH
export BUILD_WITH_COLORS=0

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
  mkdir -p ~/bin
  curl https://dl-ssl.google.com/dl/googlesource/git-repo/repo > ~/bin/repo
  chmod a+x ~/bin/repo
fi

if [ -z "$BUILD_USER_ID" ]
then
  export BUILD_USER_ID=$(whoami)
fi

git config --global user.name $BUILD_USER_ID@androidarmv6
git config --global user.email jenkins@androidarmv6.org

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


# remove non-core repos
rm -fr kernel/
rm -fr device/lge/
rm -fr device/samsung/
rm -fr device/zte/
rm -fr vendor/lge/
rm -fr vendor/samsung/
rm -fr vendor/zte/

# remove manifests
rm -rf .repo/manifests*
rm -f .repo/local_manifests/dyn-*.xml
rm -f .repo/local_manifest.xml

if [[ "$SYNC_PROTO" == "ssh" ]]
then
  repo init -u ssh://git@github.com/androidarmv6/android.git -b $CORE_BRANCH $MANIFEST
else
  repo init -u $SYNC_PROTO://github.com/androidarmv6/android.git -b $CORE_BRANCH $MANIFEST
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
  export CCACHE_DIR=/ccj/$DEVICE
  mkdir -p $CCACHE_DIR
fi

if [ -f ~/.jenkins_profile ]
then
  . ~/.jenkins_profile
fi

mkdir -p .repo/local_manifests
rm -f .repo/local_manifest.xml

echo Core Manifest:
cat .repo/manifest.xml

echo Syncing...

if [ "$SIGN_BUILD" = "true" ]
then
  rm -rf $WORKSPACE/$REPO_BRANCH/build_env
  # androidarmv6 keys... for more information: build/target/product/security/README
  git clone git@github.com:androidarmv6/build_env.git $WORKSPACE/$REPO_BRANCH/build_env -b master
  if [ -d "$WORKSPACE/$REPO_BRANCH/build_env/keys" ]
  then
    export OTA_PACKAGE_SIGNING_KEY=build_env/keys/platform
    export DEFAULT_SYSTEM_DEV_CERTIFICATE=build_env/keys/releasekey
    export OTA_PACKAGE_SIGNING_DIR=build_env/keys
  fi
  # if sync fails:
  # clean repos (uncommitted changes are present), don't delete roomservice.xml, don't exit
  repo sync -d -c -f -j16
  check_result "repo sync failed.", false, false
  # sync again, delete roomservice.xml if sync fails
  repo sync -d -c -f -j4
  check_result "repo sync failed.", false, true
fi

# last sync, delete roomservice.xml and exit if sync fails
repo sync -d -c -f -j8
check_result "repo sync failed.", true, true

# SUCCESS
echo Sync complete.

$WORKSPACE/hudson/cm-setup.sh

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
rmdir $TEMPSTASH

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
    python $WORKSPACE/hudson/repopick.py $GERRIT_CHANGES
    check_result "gerrit picks failed."
  else
    python $WORKSPACE/hudson/repopick.py $(curl $GERRIT_CHANGES)
    check_result "gerrit picks failed."
  fi
  if [ ! -z "$GERRIT_XLATION_LINT" ]
  then
    python $WORKSPACE/hudson/xlationlint.py $GERRIT_CHANGES
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
WORKSPACE=$WORKSPACE LUNCH=$LUNCH bash $WORKSPACE/hudson/changes/buildlog.sh 2>&1
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
if [ "$JOB_NAME" = "cm-recovery" ]
then
  time mka recoveryzip recoveryimage #checkapi
else
  time mka bacon recoveryzip recoveryimage #checkapi
fi
check_result "Build failed."

if [ $USE_CCACHE -eq 1 ]
then
  echo "============================================"
  ccache -V
  echo "============================================"
  ccache -s
  echo "============================================"
fi

# ClamAV virus scan
if [ "$VIRUS_SCAN" = "true" ]
then
  CLAMAV_SIGNATURE=`clamdscan --version`
  echo "Scanning for viruses with $CLAMAV_SIGNATURE..."
  clamdscan --infected --multiscan --fdpass $OUT > $WORKSPACE/archive/virusreport.txt
  SCAN_RESULT=$?
  if [ $SCAN_RESULT -eq 0 ]
  then
    echo "No virus detected."
  elif [ $SCAN_RESULT -eq 1 ]
  then
    echo Virus FOUND. Removing $OUT...
    make clobber >/dev/null
    rm -fr $OUT
    if [ ! -z "$GERRIT_CHANGE_NUMBER" ] && [ ! -z "$GERRIT_PATCHSET_NUMBER" ] && [ ! -z "$BUILD_URL" ]
    then
      ssh -p 29418 review.androidarmv6.org gerrit review $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER --code-review -1 --message "'$BUILD_URL : VIRUS FOUND'"
    fi
    exit 1
  fi
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

    OTASCRIPT=$(get_meta_val "ota_script_path")

    override_device=$(get_meta_val "override_device")
    if [ ! -z "$override_device" ]
    then
        OTASCRIPT="$OTASCRIPT --override_device=$override_device"
    fi

    extras_file=$(get_meta_val "extras_file")
    if [ ! -z "$extras_file" ]
    then
        OTASCRIPT="$OTASCRIPT --extras_file=$extras_file"
    fi

    no_separate_recovery=$(get_meta_val "no_separate_recovery")
    if [ ! -z "$no_separate_recovery" -a "$no_separate_recovery" = "true" ]
    then
        OTASCRIPT="$OTASCRIPT --no_separate_recovery=true"
    fi

    if [ -z "$WITH_GMS" -o "$WITH_GMS" = "false" ]
    then
        OTASCRIPT="$OTASCRIPT --backup=true"
    fi

    ./build/tools/releasetools/sign_target_files_apks -e Term.apk= -d $OTA_PACKAGE_SIGNING_DIR $OUT/obj/PACKAGING/target_files_intermediates/$TARGET_PRODUCT-target_files-$BUILD_NUMBER.zip $OUT/$MODVERSION-signed-intermediate.zip
    $OTASCRIPT -k $OTA_PACKAGE_SIGNING_DIR/releasekey $OUT/$MODVERSION-signed-intermediate.zip $WORKSPACE/archive/cm-$MODVERSION.zip
    md5sum $WORKSPACE/archive/cm-$MODVERSION.zip > $WORKSPACE/archive/cm-$MODVERSION.zip.md5sum
    if [ "$FASTBOOT_IMAGES" = "true" ]
    then
       ./build/tools/releasetools/img_from_target_files $OUT/$MODVERSION-signed-intermediate.zip $WORKSPACE/archive/cm-$MODVERSION-fastboot.zip
       md5sum $WORKSPACE/archive/cm-$MODVERSION-fastboot.zip > $WORKSPACE/archive/cm-$MODVERSION-fastboot.zip.md5sum
    fi

    # file name conflict
    function getFileName() {
	echo ${1##*/}
    }
    DOWNLOAD_ANDROIDARMV6_ORG_DEVICE=~/download_androidarmv6_org/CyanogenModOTA/_builds/$DEVICE
    DOWNLOAD_ANDROIDARMV6_ORG_DELTAS=~/download_androidarmv6_org/CyanogenModOTA/_deltas/$DEVICE
    DOWNLOAD_ANDROIDARMV6_ORG_LAST=~/download_androidarmv6_org/CyanogenModOTA/_last/$SDKVERSION/$DEVICE
    if [ "$RELEASE_TYPE" = "CM_RELEASE" ]
    then
      DOWNLOAD_ANDROIDARMV6_ORG_DEVICE="$DOWNLOAD_ANDROIDARMV6_ORG_DEVICE/stable"
      DOWNLOAD_ANDROIDARMV6_ORG_DELTAS="$DOWNLOAD_ANDROIDARMV6_ORG_DELTAS/stable"
      DOWNLOAD_ANDROIDARMV6_ORG_LAST="$DOWNLOAD_ANDROIDARMV6_ORG_LAST/stable"
    else
      # Remove older nightlies and deltas
      find $DOWNLOAD_ANDROIDARMV6_ORG_DEVICE -name "cm*NIGHTLY*" -not -path "*/stable/*" -type f -mtime +63 -delete
      find $DOWNLOAD_ANDROIDARMV6_ORG_DELTAS -name "incremental-*" -not -path "*/stable/*" -type f -mtime +70 -delete
    fi
    mkdir -p $DOWNLOAD_ANDROIDARMV6_ORG_DEVICE
    mkdir -p $DOWNLOAD_ANDROIDARMV6_ORG_DELTAS
    mkdir -p $DOWNLOAD_ANDROIDARMV6_ORG_LAST

    CM_ZIP=
    for f in $(ls $WORKSPACE/archive/cm-*.zip)
    do
      CM_ZIP=$(basename $f)
    done
    if [ -f $DOWNLOAD_ANDROIDARMV6_ORG_DEVICE/$CM_ZIP ]
    then
      echo "File $CM_ZIP exists on download.androidarmv6.org"
      echo "Only 1 build is allowed for 1 device on 1 day"
      make clobber >/dev/null
      rm -fr $OUT
      exit 1
    fi

    # changelog
    cp $WORKSPACE/archive/CHANGES.txt $DOWNLOAD_ANDROIDARMV6_ORG_DEVICE/cm-$MODVERSION.txt

    # incremental
    if [ "$FORCE_FULL_OTA" = "true" ]
    then
      rm -rf $DOWNLOAD_ANDROIDARMV6_ORG_LAST/*.zip
      rm -rf $DOWNLOAD_ANDROIDARMV6_ORG_LAST/buildnumber
    fi
    FILE_MATCH_intermediates=*.zip
    FILE_LAST_intermediates=$(getFileName $(ls -1 $DOWNLOAD_ANDROIDARMV6_ORG_LAST/$FILE_MATCH_intermediates))
    if [ "$FILE_LAST_intermediates" != "" ]; then
      OTASCRIPT="$OTASCRIPT --incremental_from=$DOWNLOAD_ANDROIDARMV6_ORG_LAST/$FILE_LAST_intermediates"
      LAST_BUILD_NUMBER=$(cat $DOWNLOAD_ANDROIDARMV6_ORG_LAST/buildnumber)
      $OTASCRIPT -k $OTA_PACKAGE_SIGNING_DIR/releasekey $OUT/$MODVERSION-signed-intermediate.zip $DOWNLOAD_ANDROIDARMV6_ORG_DELTAS/incremental-$LAST_BUILD_NUMBER-$BUILD_NUMBER.zip
      md5sum $DOWNLOAD_ANDROIDARMV6_ORG_DELTAS/incremental-$LAST_BUILD_NUMBER-$BUILD_NUMBER.zip > $DOWNLOAD_ANDROIDARMV6_ORG_DELTAS/incremental-$LAST_BUILD_NUMBER-$BUILD_NUMBER.zip.md5sum
    fi
    rm -rf $DOWNLOAD_ANDROIDARMV6_ORG_LAST/*.zip
    rm -rf $DOWNLOAD_ANDROIDARMV6_ORG_LAST/buildnumber
    cp $OUT/$MODVERSION-signed-intermediate.zip $DOWNLOAD_ANDROIDARMV6_ORG_LAST/$MODVERSION-signed-intermediate.zip
    echo $BUILD_NUMBER > $DOWNLOAD_ANDROIDARMV6_ORG_LAST/buildnumber

    unset MINIGZIP

    # /archive
    for f in $(ls $WORKSPACE/archive/cm-*.zip*)
    do
      cp $f $DOWNLOAD_ANDROIDARMV6_ORG_DEVICE
    done

    # /recovery
    if [ "$EXPORT_RECOVERY" = "true" -a -f $OUT/recovery.img ]
    then
      cp $OUT/recovery.img $DOWNLOAD_ANDROIDARMV6_ORG_DEVICE/recovery-$DEVICE.img
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

