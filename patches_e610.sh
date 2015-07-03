#!/bin/bash

cd $WORKSPACE/$REPO_BRANCH

# frameworks/av : Add back missing msm7x27a to fix compilation
cherries+=(79582)

# Build : Add back support for msm7x27a Board
cherries+=(79581)

# build: Add option to disable block-based ota
cherries+=(78849)

# init: change permission for lowmemorykiller back to 664
cherries+=(82787)

# Camera2: Remove settings preferences only once
cherries+=(81019)

# Allow low RAM devices have multiple users
cherries+=(78423)

# Fix memory leak in system_server when screen on/off
cherries+=(82572)

# nl80211: Add unhandled attributes from wpa_supplicant
cherries+=(81764)

# install: disable signature checking on eng and userdebug builds
cherries+=(81797)

$WORKSPACE/$REPO_BRANCH/build/tools/repopick.py -b ${cherries[@]}
