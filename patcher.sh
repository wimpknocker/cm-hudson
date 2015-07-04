#!/usr/bin/env bash

PATCHDIR=$WORKSPACE/patches/$REPO_BRANCH/$DEVICE
PATCHTO=$WORKSPACE/$REPO_BRANCH
UNATTENDED=${1}

echo $PATCHDIR
echo $PATCHTO

cd $PATCHDIR
for LINE in $(find -name *.patch | sort )
do
    if [[ $UNATTENDED -ne 1 ]]; then
      clear
    fi
    echo "patch = $PATCHDIR/$LINE"
    PATCH=$PATCHDIR/$LINE
    REPO=$(dirname $LINE)
    echo "repo = $REPO"
    cd $PATCHTO
    cd $REPO
    RESULT=$(patch -p1 --no-backup-if-mismatch < $PATCH)
    echo -e "${RESULT}"
    if [[ $(echo $RESULT | grep -c FAILED) -gt 0 ]]; then
      echo "Fail!"
      if [[ $UNATTENDED -eq 1 ]]; then
        exit 9
      else
        read -p "Patch Failed!" yn
        break;
      fi
    fi
    if [[ $(echo $RESULT | grep -c "saving rejects to file") -gt 0 ]]; then
      echo "Fail!"
      echo "Fix the patch!"
      if [[ $UNATTENDED -eq 1 ]]; then
        exit 9
      else
        read -p "Patch Rejects!" yn
        break;
      fi
    fi
    if [[ $(echo $RESULT | grep -c "Skip this patch") -gt 0 ]]; then
      echo "Fail!"
      echo "Fix the patch"
      if [[ $UNATTENDED -eq 1 ]]; then
        exit 9
      else
        read -p "Patch Skipped!" yn
        break;
      fi
    fi
    cd $PATCHTO
done

cd $PATCHDIR
for LINE in $(find -name *.apply | sort )
do
    if [[ $UNATTENDED -ne 1 ]]; then
      clear
    fi
    echo "patch = $PATCHDIR/$LINE"
    PATCH=$PATCHDIR/$LINE
    REPO=$(dirname $LINE)
    echo "repo = $REPO"
    cd $PATCHTO
    cd $REPO
    RESULT=$(git apply --whitespace=nowarm -v $PATCH 2>$1)
    echo -e "${RESULT}"
    if [[ $(echo $RESULT | grep -c error:) -gt 0 ]]; then
      echo "Fail!"
      echo "Fix the patch!"
      if [[ $UNATTENDED -eq 1 ]]; then
        exit 9
      else
        read -p "Patch Error!" yn
        break;
      fi
    fi
    cd $PATCHTO
done
