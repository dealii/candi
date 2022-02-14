#!/bin/bash
## ---------------------------------------------------------------------
##
## Copyright (C) 2018 - 2021 by the deal.II authors
##
## This file is part of the deal.II library.
##
## The deal.II library is free software; you can use it, redistribute
## it, and/or modify it under the terms of the GNU Lesser General
## Public License as published by the Free Software Foundation; either
## version 2.1 of the License, or (at your option) any later version.
## The full text of the license can be found in the file LICENSE at
## the top level of the deal.II distribution.
##
## ---------------------------------------------------------------------

#
# This file contains a number of common functions used all indent scripts
#

#
# This function checks that we are in the root directory and that shfmt is
# available. It is called by both indent.sh and indent_all.sh to ensure that
# the rest of the indentation pipeline makes sense.
#

#
# DEAL_II_SHFMT can be used to change the default version of shfmt
#

export DEAL_II_SHFMT="${DEAL_II_SHFMT:-shfmt}"
export DEAL_II_SHFMT_OPTIONS="-ln bash -i 2 -bn -ci -sr"

checks() {
  if test ! -d contrib -o ! -d deal.II-toolchain; then
    echo "*** This script must be run from the top-level directory of candi."
    exit 1
  fi

  if ! [ -x "$(command -v "${DEAL_II_SHFMT}")" ]; then
    echo "***   No shfmt program found."
    echo "***"
    echo "***   Install shfmt via snap: sudo snap install shfmt"
    exit 1
  fi

  # Make sure to have the right version.
  SHFMT_VERSION="$(${DEAL_II_SHFMT} --version)"
  SHFMT_MAJOR_VERSION=$(echo "${SHFMT_VERSION}" | sed 's/^[^0-9]*\([0-9]*\).*$/\1/g')
  SHFMT_MINOR_VERSION=$(echo "${SHFMT_VERSION}" | sed 's/^[^0-9]*[0-9]*\.\([0-9]*\).*$/\1/g')

  if [ "${SHFMT_MAJOR_VERSION}" -ne 3 ] || [ "${SHFMT_MINOR_VERSION}" -ne 3 ]; then
    echo "***   This indent script requires shfmt version 3.3.1,"
    echo "***   but version ${SHFMT_MAJOR_VERSION}.${SHFMT_MINOR_VERSION} was found instead."
    echo "***"
    echo "***   Install shfmt via snap: sudo snap install shfmt"
    exit 1
  fi

  # check formatting of usernames and email addresses, examples that will be detected:
  # not-using-a-name <a@b.com>
  # John Doe <doe@macbook.local>
  # Jane Doe <a@nodomain>
  #
  # For commits already in the history, please see .mailmap in the root directory.
  #
  # Note that we currently allow email addresses of the form
  # Luca Heltai <luca-heltai@users.noreply.github.com>
  # as these are generated when using the website to commit.
  #
  # Finally, to stay sane, just go back until the beginning of 2019 for now.
  #
  # first user names:
  git log --since "2022-01-01" --format="%aN" --no-merges | sort -u | while read name; do
    words=($name)
    if [ "${#words[@]}" -lt "2" ]; then
      echo "invalid author '$name' without firstname and lastname"
      echo ""
      echo "hint: for possible solutions, consult the webpage:"
      echo "      https://github.com/dealii/dealii/wiki/Indentation#commit-authorship"
      exit 2
    fi
  done || exit 2

  # now emails:
  git log --since "2022-01-01" --format="%aE" --no-merges | sort -u | while read email; do
    words=($name)
    if ! echo "$email" | grep -q "\."; then
      echo "invalid email '$email'"
      echo ""
      echo "hint: for possible solutions, consult the webpage:"
      echo "      https://github.com/dealii/dealii/wiki/Indentation#commit-authorship"
      exit 3
    fi
    if ! echo "$email" | grep -q -v -e "\.local$"; then
      echo "invalid email '$email'"
      echo ""
      echo "hint: for possible solutions, consult the webpage:"
      echo "      https://github.com/dealii/dealii/wiki/Indentation#commit-authorship"
      exit 3
    fi
  done || exit 3

}

#
# Mac OSX's mktemp doesn't know the --tmpdir option without argument. So,
# let's do all of that by hand:
#
export TMPDIR="${TMPDIR:-/tmp}"

export REPORT_ONLY="${REPORT_ONLY:-false}"

#
# If REPORT_ONLY is set to "true", this function reports a formatting issue
# if file "${1}" and tmpfile "${2}" don't match (using the error message
# "${3}"), or, if set to "false" silently replaces file "${1}" with "${2}".
#

fix_or_report() {
  file="${1}"
  tmpfile="${2}"
  message="${3}"

  if ! diff -q "${file}" "${tmpfile}" > /dev/null; then
    if ${REPORT_ONLY}; then
      echo "    ${file}  -  ${message}"
    else
      mv "${tmpfile}" "${file}"
    fi
  fi
}
export -f fix_or_report

#
# In order to format shell-script files we have to make sure that we override
# the source/header file only if the actual contents changed. We use temporary
# file and diff as a workaround.
#

format_file() {
  file="${1}"
  tmpfile="$(mktemp "${TMPDIR}/$(basename "$1").tmp.XXXXXXXX")"

  ${DEAL_II_SHFMT} ${DEAL_II_SHFMT_OPTIONS} "${file}" > "${tmpfile}"
  fix_or_report "${file}" "${tmpfile}" "file indented incorrectly"
  rm -f "${tmpfile}"
}
export -f format_file

#
# Remove trailing whitespace.
#

remove_trailing_whitespace() {
  file="${1}"
  tmpfile="$(mktemp "${TMPDIR}/$(basename "$1").tmp.XXXXXXXX")"

  #
  # Mac OS uses BSD sed (other than GNU sed in Linux),
  # so it doesn't recognize \s as 'spaces' or + as 'one or more'.
  #
  sed 's/[[:space:]]\{1,\}$//g' "${file}" > "${tmpfile}"
  if ! diff -q "${file}" "${tmpfile}" > /dev/null; then
    mv "${tmpfile}" "${file}"
  fi
  rm -f "${tmpfile}"
}
export -f remove_trailing_whitespace

#
# Convert DOS formatted files to unix file format by stripping out
# carriage returns (15=0x0D):
#

dos_to_unix() {
  file="${1}"
  tmpfile="$(mktemp "${TMPDIR}/$(basename "$1").tmp.XXXXXXXX")"

  tr -d '\015' < "${file}" > "${tmpfile}"

  fix_or_report "${file}" "${tmpfile}" "file has non-unix line-ending '\\r\\n'"
  rm -f "${tmpfile}"
}
export -f dos_to_unix

#
# Fix permissions
#

fix_permissions() {
  file="${1}"

  case "${OSTYPE}" in
    darwin*)
      PERMISSIONS="$(stat -f '%a' ${file})"
      ;;
    *)
      PERMISSIONS="$(stat -c '%a' ${file})"
      ;;
  esac

  if [ "${PERMISSIONS}" != "644" ]; then
    if ${REPORT_ONLY}; then
      echo "    ${file}  -  file has incorrect permissions"
    else
      chmod 644 "${file}"
    fi
  fi
}
export -f fix_permissions

#
# Collect all files found in a list of directories "${1}" matching a
# regular expression "${2}", and process them with a command "${3}" on 10
# threads in parallel.
#
# The command line is a bit complicated, so let's discuss the more
# complicated arguments:
# - For 'find', -print0 makes sure that file names are separated by \0
#   characters, as opposed to the default \n. That's because, surprisingly,
#   \n is a valid character in a file name, whereas \0 is not -- so it
#   serves as a good candidate to separate individual file names.
# - For 'xargs', -0 does the opposite: it separates filenames that are
#   delimited by \0
# - the option "-P 10" starts up to 10 processes in parallel. -0 implies '-L 1'
#   (one argument to each command) so each launch of clang-format corresponds
#   to exactly one file.
#

process() {
  directories=$1
  case "${OSTYPE}" in
    darwin*)
      find -E ${directories} -regex "${2}" -print0 \
        | xargs -0 -P 10 -I {} bash -c "${3} {}"
      ;;
    *)
      find ${directories} -regextype egrep -regex "${2}" -print0 \
        | xargs -0 -P 10 -I {} bash -c "${3} {}"
      ;;
  esac
}

#
# Variant of above function that only processes files that have changed
# since the last merge commit to master. For this, we collect all files
# that
#  - are new
#  - have changed since the last merge commit to master
#

process_changed() {
  LAST_MERGE_COMMIT="$(git log --format="%H" --merges --max-count=1 master)"
  COMMON_ANCESTOR_WITH_MASTER="$(git merge-base "${LAST_MERGE_COMMIT}" HEAD)"

  case "${OSTYPE}" in
    darwin*)
      XARGS="xargs -E"
      ;;
    *)
      XARGS="xargs --no-run-if-empty -d"
      ;;
  esac

  (
    git ls-files --others --exclude-standard -- ${1}
    git diff --name-only $COMMON_ANCESTOR_WITH_MASTER -- ${1}
  ) \
    | sort -u \
    | xargs -n 1 ls -d 2> /dev/null \
    | grep -E "^${2}$" \
    | ${XARGS} '\n' -P 10 -I {} bash -c "${3} {}"
}

#
# Ensure only a single newline at end of files
#
ensure_single_trailing_newline() {
  f=$1

  # Remove newlines at end of file
  # Check that the current line only contains newlines
  # If it doesn't match, print it
  # If it does match and we're not at the end of the file,
  # append the next line to the current line and repeat the check
  # If it does match and we're at the end of the file,
  # remove the line.
  sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $f > $f.tmpi

  # Then add a newline to the end of the file
  # '$' denotes the end of file
  # 'a\' appends the following text (which in this case is nothing)
  # on a new line
  sed -e '$a\' $f.tmpi > $f.tmp

  diff -q $f $f.tmp > /dev/null || mv $f.tmp $f
  rm -f $f.tmp $f.tmpi
}
export -f ensure_single_trailing_newline
