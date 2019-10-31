#!/bin/bash

function join_by {
  local IFS="$1"
  shift
  echo "$*"
}

function setup_github_ssh {
  eval "$(ssh-agent -s)"
  mkdir -p ~/.ssh
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
  ssh-add <(echo "$SSH_KEY")
}

function create_private_yml {
  blobstore_provider=$(yq r config/final.yml blobstore.provider)

  if [[ $blobstore_provider == "gcs" ]]; then
    cat << EOF > config/private.yml
---
blobstore:
  options:
    credentials_source: static
    json_key: |
      $(echo ${JSON_KEY})
EOF
  else
  # setup private.yml used by `create-release --final`
    cat << EOF > config/private.yml
---
blobstore:
  provider: s3
  options:
    bucket_name: $BLOBSTORE_BUCKET
    access_key_id: $S3_ACCESS_KEY
    secret_access_key: $S3_SECRET_KEY
    credentials_source: static
EOF
  fi
}

function create_tagged_release {
  version=$1

  create_private_yml

  # create final release and commit artifcats
  bosh -n create-release --sha2 --final \
    --tarball ../github-release/release.tgz \
    --version "$version"
  git add .
  git commit -m "Create final release"

  final_release_abbrev=$(git rev-parse --abbrev-ref HEAD)
  final_release_sha=$(git rev-parse HEAD)
  git tag "v$version" $final_release_sha
}

function build_github_release_info {
  release_name=$1
  version=$2
  commit_range=$3
  github_release_dir=$4

  set +x
    BUMPER_RESULT=$( (bumper --commit-range ${commit_range} --verbose --no-color) 2>&1 | grep -v "Bump modules")
    GIT_DIFF_JOBS=$(git diff ${commit_range} -- jobs)
  set -x

  tag_name="v$version"

  # write out github release files
  echo "$release_name $version" > ${github_release_dir}/name
  echo $tag_name > ${github_release_dir}/tag
  printf '## BUMPER OUTPUT\n%s\n\n' "$BUMPER_RESULT" >> ${github_release_dir}/body
  printf '## GIT DIFF jobs directory\n```diff\n%s\n```\n\n' "${GIT_DIFF_JOBS}" >> ${github_release_dir}/body
}
