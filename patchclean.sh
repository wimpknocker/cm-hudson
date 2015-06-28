#!/usr/bin/env bash

PATCHDIR=$WORKSPACE/patches/$REPO_BRANCH
PATCHTO=$WORKSPACE/$REPO_BRANCH
UNATTENDED=${1}

echo $PATCHTO
cd $PATCHTO
for LINE in $(echo $(find -name *.patch); echo $(find -name *.apply))
do
  if [[ $UNATTENDED -ne 1 ]]; then
    clear
  fi
  echo "clearing = $LINE"
  REPO=$(dirname $LINE)
  echo "repo = $PATCHDIR$REPO"
  cd $PATCHTO
  cd $REPO
  git add .
  git stash
  find -name *.orig | while read LINE; do rm $LINE; done
  find -name *.rej | while read LINE; do rm $LINE; done
  git clean -f
  git stash clear
  cd $PATCHTO
done
