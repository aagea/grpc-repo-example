#!/usr/bin/env bash

# Copyright 2019 Alvaro Agea
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

GITHUB_USER=${GITHUB_USER-"aagea"}
REPO_PATH=${REPO_PATH-/opt/protolangs}
CURRENT_BRANCH=${CURRENT_BRANCH-"branch-not-available"}
DRY=${DRY-"false"}

# Helper for adding a directory to the stack and echoing the result
function enterDir {
  echo "Entering $1"
  pushd $1 > /dev/null
}

# Helper for popping a directory off the stack and echoing the result
function leaveDir {
  echo "Leaving `pwd`"
  popd > /dev/null
}



# Iterates through all of the languages listed in the services .protolangs file
# and compiles them individually
function buildProtoForTypes {
  target=${1%/}

  if [[ -f .protolangs ]]; then
    while read lang; do
      reponame="grpc-$target-$lang"

      rm -rf ${REPO_PATH}/${reponame}

      echo "Cloning repo: git@github.com:$GITHUB_USER/$reponame.git"

      # Clone the repository down and set the branch to the automated one
      git clone git@github.com:${GITHUB_USER}/${reponame}.git ${REPO_PATH}/${reponame}
      setupBranch ${REPO_PATH}/${reponame}

      # Use the docker container for the language we care about and compile
      docker run -v `pwd`:/defs namely/protoc-all:1.15 -d ${target} -i . -i /usr/local/include/google \
        -o ${target}/pb-${lang} -l ${lang} --with-docs --with-gateway \
      /


      # Copy the generated files out of the pb-* path into the repository
      # that we care about
      cp -R pb-${lang}/github.com/${GITHUB_USER}/grpc-${target}-
      cp -R pb-${lang}/* ${REPO_PATH}/${reponame}/

      if [["${DRY}" == "true"]]; then
        echo "Commit and push stage is omitted"
      else
        commitAndPush ${REPO_PATH}/${reponame}
      fi

    done < .protolangs
  fi
}



function setupBranch {
  enterDir $1

  echo "Creating branch"

  if ! git show-branch ${CURRENT_BRANCH}; then
    git branch ${CURRENT_BRANCH}
  fi

  git checkout ${CURRENT_BRANCH}

  if git ls-remote --heads --exit-code origin $CURRENT_BRANCH; then
    echo "Branch exists on remote, pulling latest changes"
    git pull origin ${CURRENT_BRANCH}
  fi

  leaveDir
}

function commitAndPush {
  enterDir $1

  git add -N .

  if ! git diff --exit-code > /dev/null; then
    # Defining the repository version
    if [[ ! -f VERSION ]]; then
      echo "Creating version file"
      echo "0.0.0" > VERSION
    fi

    local currentVersion=cat VERSION
    local versionArr=(`echo ${currentVersion} | tr '.' ' '`)
    local majorVersion=${versionArr[0]}
    local minorVersion=${versionArr[1]}
    local patchVersion=${versionArr[2]}

    local newPatchVersion=$((patchVersion+1))
    local newVersion="${majorVersion}.${minorVersion}.${newPatchVersion}"
    echo "New Version: ${newVersion}"
    echo ${newVersion} > VERSION

    git add .
    git commit -m "Auto Creation of Proto"
    git push origin HEAD

    #Creating tag
    git tag -a -m "Auto generated version ${newVersion}." "v${newVersion}"
    git push origin --tags
  else
    echo "No changes detected for $1"
  fi

  leaveDir
}

# Enters the directory and starts the build / compile process for the services
# protobufs
function buildDir {
  currentDir="$1"
  echo "Building directory \"$currentDir\""

  enterDir ${currentDir}

  buildProtoForTypes ${currentDir}

  leaveDir
}

function getUpdatedDirs {
 local  __resultvar=$1
  if ! [[ "$__resultvar" ]]; then
    echo "getUpdatedDirs invoked exception"
    exit -1
  fi


  local mergeNumber=1
  local gitLastCommit=$(git rev-parse HEAD)
  local gitLastMergeCommit=$(git log --merges -n ${mergeNumber} --pretty=format:"%H")
  if [[ "$gitLastCommit" == "$gitLastMergeCommit" ]]; then
    mergeNumber=$(( $mergeNumber + 1))
  fi
  local foundMerge=0
  while [[ ${foundMerge} -eq 0 ]]; do
    local mergeLog=$(git log --merges -n ${mergeNumber} --pretty=format:"%s" | awk -v nr="$mergeNumber" '{if (NR==nr) print $0}')
    if [[ ${mergeLog} == *"Merge branch 'master' into"* ]]; then
      mergeNumber=$(( $mergeNumber + 1))
    else
      gitLastCommit=$(git log --merges -n ${mergeNumber} --pretty=format:"%H" | awk -v nr="$mergeNumber" '{if (NR==nr) print $0}')
      foundMerge=1
    fi
  done


  echo "Last commit merge: ${gitLastMergeCommit}"
  local modifiedResult=$(git diff --name-only ${gitLastCommit} ${gitLastMergeCommit} | grep "^.*\/.*.proto$" | awk -F/ '{print $1}')
  echo "Modified directories: ${modifiedResult}"
  eval ${__resultvar}="'$modifiedResult'"
}



function buildDiff {
 echo "Building only modified protocol directories"
 local dirs=""
 getUpdatedDirs dirs

 mkdir -p ${REPO_PATH}
 if [[ "$dirs" == "" ]]; then
   echo "No protocol buffer was modified since last merge"
   exit 0
 fi
 for d in ${dirs}; do
   buildDir ${d}
 done
}


function buildTarget {
    TARGET=$1
    if ! [[ "${TARGET}" ]]; then
        echo "Must indicate a target"
        exit -1
    fi
    buildDir ${TARGET}
}

# Finds all directories in the repository and iterates through them calling the
# compile process for each one
function buildAll {
  for d in */; do
    buildDir ${d}
  done
}

function init {
    echo "Building service's protocol buffers"

    echo "GITHUB_USER = $GITHUB_USER"
    echo "REPO_PATH = $REPO_PATH"
    echo "CURRENT_BRANCH = $CURRENT_BRANCH"
    echo "BUILD_OPTION = $BUILD_OPTION"
    echo "DRY = $DRY"

    mkdir -p "$REPO_PATH"
}

BUILD_OPTION=$1
if ! [[ "$BUILD_OPTION" ]]; then
    echo "Must indicate the build option"
    exit -1
fi
init
if [[ "${BUILD_OPTION}" == "all" ]]; then
   buildAll
elif [[ "${BUILD_OPTION}" == "diff" ]]; then
   buildDiff
elif [[ "${BUILD_OPTION}" == "target" ]]; then
   buildTarget $2
else
   echo "Must indicate a correct build option [all|diff|target]"
   exit -1
fi
