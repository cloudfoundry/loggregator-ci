require 'rspec'
require_relative 'task'

# - authors:
#   - contact: contact@sample-author.io
#     homepage: https://github.com/sample-author
#     name: Sample-Author
#   binaries:
#   - checksum: 2a087d5cddcfb057fbda91e611c33f46
#     platform: osx
#     url: https://github.com/sample-author/new_plugin/releases/download/v1.0.0/echo_darwin
#   - checksum: b4550d6594a3358563b9dcb81e40fd66
#     platform: win64
#     url: https://github.com/sample-author/new_plugin/releases/download/v1.0.0/echo_win64.exe
#   - checksum: f6540d6594a9684563b9lfa81e23id93
#     platform: linux32
#     url: https://github.com/sample-author/new_plugin/releases/download/v1.0.0/echo_linux32
#   company:
#   created: 2015-01-31T00:00:00Z
#   description: new_plugin to be made available for the CF community
#   homepage: https://github.com/sample-author/new_plugin
#   name: new_plugin
#   updated: 2015-01-31T00:00:00Z
#   version: 1.0.0

# Flow steps:
#   1. Check for latest published release
#   1. Ensure PR does not already exist
#   1. Create a branch based on master for PR on fork of cli-plugin-repo
#   1. Update yaml
#   1. Create PR of branch on fork to cli-plugin-repo master
