# Contributing to ActiveDirectory gem

## Fork the repo in Github

## Make a local clone of your fork

    $ git clone git@github.com:<your github account name>/active_directory.git

## Create a branch for your work

    $ git checkout -b my_cool_feature

## Installation

    $ bundle install
    $ bundle binstub rspec-core

## Testing with a live connection to an Active Directory Server

In the `config` directory, modify the `active_directory.yml.sample`
file and save it as `active_directory.yml`.

Run the live connection tests:

    $ bin/rspec livewire-tests

