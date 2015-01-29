#!/usr/bin/env bash

version=$1

if [ -z "$version" ]; then
    echo "Must specify the version"
    exit -1
fi

source /etc/profile.d/chruby.sh

chruby $version

gem install bundler
gem install pry
gem install pry-byebug
