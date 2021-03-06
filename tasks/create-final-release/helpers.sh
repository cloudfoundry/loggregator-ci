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

function get_go_version {
  release_tarball=$1

  tmp_dir=$(mktemp -d)
  tar xf ${release_tarball} -C ${tmp_dir} --wildcards 'packages/golang-*'
  go_linux_version=$(tar -tf ${tmp_dir}/packages/golang-*-linux.tgz --wildcards '*go*.tar.gz' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

  if [[ -f ${tmp_dir}/packages/golang-*-windows.tgz ]]; then
    go_windows_version=$(tar -tf ${tmp_dir}/packages/golang-*-windows.tgz '*go*.zip' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    if [[ "$go_windows_version" != "$go_linux_version" ]]; then
      echo "Go windows version ($go_windows_version) is different than Go linux version ($go_linux_version)"
      exit 1
    fi
  fi

  echo "$go_linux_version"
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
  printf '**Changelog**\n' >> ${github_release_dir}/body
  if only_auto_bumpable_commits "${commit_range}"; then
    echo '- Bump modules'  >> ${github_release_dir}/body
  else
    printf '## BUMPER OUTPUT\n%s\n\n' "$BUMPER_RESULT" >> ${github_release_dir}/body
  fi

  if [[ ! -z "$GIT_DIFF_JOBS" ]]; then
    printf '## GIT DIFF jobs directory\n```diff\n%s\n```\n\n' "${GIT_DIFF_JOBS}" >> ${github_release_dir}/body
  fi

  printf '\n**GO Version**: `%s`\n\n' "$(get_go_version ${github_release_dir}/release.tgz)" >> ${github_release_dir}/body
}

function only_auto_bumpable_commits {
  commit_range=$1

  set +x
    while read -r commit ; do
      commit=${commit//\'/}
      if [[ $commit = *[![:space:]]* ]]; then
        auto_bumpable_commits+="${commit}|"
      fi
    done  <<< "$AUTO_BUMPABLE_COMMITS"
    auto_bumpable_commits=${auto_bumpable_commits::-1}
  set -x

  if [[ $(git log --oneline ${commit_range} | grep -c -v -E -- "$auto_bumpable_commits") -eq 0 ]]; then
    return 0
  fi

  return 1
}

function no_commits {
  commit_range=$1

  if [[ $(git log --oneline ${commit_range} | wc -l) -eq 0 ]]; then
    return 0
  fi

  return 1
}
