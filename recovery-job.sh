if [ -z "$HOME" ]
then
  echo HOME not in environment, guessing...
  export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

cd $WORKSPACE
mkdir -p ../recovery-builds
cd ../recovery-builds
export WORKSPACE=$PWD

if [ ! -d cm-hudson ]
then
  git clone git://github.com/wimpknocker/cm-hudson.git -b master
fi

cd cm-hudson
## Get rid of possible local changes
git reset --hard
git pull -s resolve

exec ./build-recovery.sh
