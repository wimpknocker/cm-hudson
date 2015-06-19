# Jenkins Job Setup

# Jenkins Variables
REPO_BRANCH
LUNCH
CLEAN "Choice=full,device"
RELEASE_TYPE "Choice=CM_NIGHTLY,CM_EXPERIMENTAL,CM_RELEASE"
SYNC_PROTO
SIGN_BUILD
CORE_BRANCH
RELEASE_MANIFEST

The job uses the following script:

```bash
curl -O -L https://raw.github.com/wimpknocker/cm-hudson/master/job.sh
. ./job.sh
```
