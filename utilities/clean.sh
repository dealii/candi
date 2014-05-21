#!/usr/bin/env bash

# This is a utility script to clean temporary files originating from
# Emacs and elsewhere

rm `find .. -name '*~' | xargs`