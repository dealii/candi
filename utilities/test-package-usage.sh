#!/usr/bin/env bash

# This is a utility script to check whether the numerous defined
# packages in Dorsal are used or not. It is used sporadically to cull
# unused packages.

# Colours for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"

cecho() {
    # Display messages in a specified colour
    COL=$1; shift
    echo -e "${COL}$@\033[0m"
}

for packagefull in ../FEniCS/packages/*.package
do
    package=`basename ${packagefull} .package`
    if [[ "${package}" != *stable ]]
    then
	grep -q ${package} ../FEniCS/platforms/*/*.platform \
	    && cecho ${GOOD} ${package} "package is used." \
	    || cecho ${BAD} ${package} "package is not used."
    fi
done