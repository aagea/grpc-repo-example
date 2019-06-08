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


DRY := "false"
CURRENT_BRANCH := "master"
REPO_PATH := "/opt/protolangs"


all: clean generate-all

.PHONY: generate-all generate-diff generate-target  clean

generate-all:
	chmod +x generate-protos.sh
	DRY=${DRY} CURRENT_BRANCH=${CURRENT_BRANCH} REPO_PATH=${REPO_PATH} ./generate-protos.sh all

generate-diff:
	chmod +x generate-protos.sh
	DRY=${DRY} CURRENT_BRANCH=${CURRENT_BRANCH} REPO_PATH=${REPO_PATH} ./generate-protos.sh diff

generate-target:
	chmod +x generate-protos.sh
	DRY=${DRY} CURRENT_BRANCH=${CURRENT_BRANCH} REPO_PATH=${REPO_PATH} ./generate-protos.sh target ${target}

clean:
	rm -Rf grpc-*-go && rm -Rf */pb-go