#!/bin/bash

# Usage:
# ./find_failed_build_with_text.sh "Text to look for"

failed_builds=$(fly -t loggregator builds -j loggregator/run-tests -c 5000 | grep failed | awk '{print $3}' )
pattern=$1

for build in $failed_builds; do
    count=$(fly watch -t loggregator -j loggregator/run-tests --build=${build} | grep "${pattern}" | wc -l)
    if [ $count -gt 0 ]; then
        echo $build
    fi
done
