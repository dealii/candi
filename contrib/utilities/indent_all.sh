#!/bin/bash
## ---------------------------------------------------------------------
##
## Copyright (C) 2012 - 2018 by the deal.II authors
##
## This file is part of the deal.II library.
##
## The deal.II library is free software; you can use it, redistribute
## it, and/or modify it under the terms of the GNU Lesser General
## Public License as published by the Free Software Foundation; either
## version 2.1 of the License, or (at your option) any later version.
## The full text of the license can be found in the file LICENSE.md at
## the top level directory of deal.II.
##
## ---------------------------------------------------------------------

#
# This script indents all source files of dealii/candi according to our usual
# code formatting standards. It is used to ensure that our code base looks
# uniform, as uniformity helps make code easier to read.
#
# While we're already touching every file, this script also makes
# sure we set permissions correctly and checks for correct unix-style line
# endings.
#
# The script needs to be executed as
#   ./contrib/utilities/indent_all.sh
# from the top-level directory of the source tree.
#
# Note: If the script is invoked with REPORT_ONLY=true set,
#   REPORT_ONLY=true ./contrib/utilities/indent_all.sh
# then indentation errors will only be reported without any actual file
# changes.
#

if [ ! -f contrib/utilities/indent_all.sh ]; then
  echo "*** This script must be run from the top-level directory of candi."
  exit 1
fi

if [ ! -f contrib/utilities/indent_common.sh ]; then
  echo "*** This script requires contrib/utilities/indent_common.sh."
  exit 1
fi

source contrib/utilities/indent_common.sh

#
# Run sanity checks:
#

checks

#
# Process all source and header files:
#

process "." ".*\.(package|platform|sh|cfg)" format_file

#
# Fix permissions and convert to unix line ending if necessary:
#

process "." ".*\.(package|platform|cfg)" fix_permissions

process "." ".*\.(package|platform|sh|cfg)" dos_to_unix

#
# Removing trailing whitespace
#

process "." ".*\.(package|platform|sh|cfg)" remove_trailing_whitespace

#
# Ensure only a single newline at end of files
#

process "." ".*\.(package|platform|sh|cfg)" ensure_single_trailing_newline
