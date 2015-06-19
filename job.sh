# CHECK DEVICE NAME
if [ -z "$GERRIT_PROJECT" ]
then
  ZIPDEVICE=$(echo $LUNCH | sed s#cm_##g | sed s#-userdebug##g | sed s#-eng##g)
  if [ -z "$ZIPDEVICE" ]
  then
    echo "EMPTY DEVICE"
    exit 1
  fi
  export ZIPDEVICE=$ZIPDEVICE
fi

# HOME
if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

# WORKSPACE
cd $WORKSPACE
mkdir -p ../cm-builds
cd ../cm-builds
export OLDWORKSPACE=$WORKSPACE
export WORKSPACE=$PWD
export

#HUDSON
if [ ! -d cm-hudson ]
then
  git clone git://github.com/wimpknocker/cm-hudson.git -b master
fi
cd cm-hudson
## Get rid of possible local changes
git reset --hard
git pull -s resolve
cd ..

# BUILD
cp -fr cm-hudson/build.sh build.sh
exec ./build.sh
