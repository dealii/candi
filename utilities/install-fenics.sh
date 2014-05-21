#!/usr/bin/env bash

# Set default values of some useful variables
export VERSION="1.0-beta"       # Latest released Dorsal version
export PREFIX=${HOME}/local     # Default download/install location
export ORIG_DIR=`pwd`           # Store original directory, so we can
				# return to it when finished

# Colours for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"
BOLD="\033[1m"

### Define helper functions ###

cecho() {
    # Display messages in a specified colour
    COL=$1; shift
    echo -e "${COL}$@\033[0m"
}

default () {
    # Export a variable, if it is not already set
    VAR="${1%%=*}"
    VALUE="${1#*=}"
    eval "[[ \$$VAR ]] || export $VAR='$VALUE'"
}

# Make a directory name more readable by replacing homedir with ~
prettify_dir() {
   echo ${1/#$HOME\//~\/}
}

# Make a directory name entered with ~ for the homedir more portable
unprettify_dir() {
   echo ${1/#~\//$HOME\/}
}

# Fetch the latest released version of Dorsal
fetch_dorsal() {
    default TMPDIR=/tmp
    cd ${TMPDIR}
    cecho ${GOOD} "Fetching the FEniCS installer files"
    wget -N http://launchpad.net/dorsal/trunk/${VERSION}/+download/dorsal-${VERSION}.tar.bz2
    if [ -d "dorsal-${VERSION}" ]
    then
	rm -fr dorsal-${VERSION}
    fi
    tar -xjf dorsal-${VERSION}.tar.bz2
    cd dorsal-${VERSION}
}

# Set up the build configuration (using some sensible defaults)
cfg_dorsal() {
    echo "PROJECT=FEniCS"               >  dorsal.cfg
    echo "DOWNLOAD_PATH=${PREFIX}/src"  >> dorsal.cfg
    echo "INSTALL_PATH=${PREFIX}"       >> dorsal.cfg
    echo "PROCS=2"                      >> dorsal.cfg
    echo "STABLE_BUILD=true"            >> dorsal.cfg
}

# Run the build script
run_dorsal() {
    ./dorsal.sh
    cd ${ORIG_DIR}
}


while :
do

    SELECTION1="Install FEniCS"
    SELECTION2="Change installation path [$(prettify_dir ${PREFIX})]"
    SELECTION3="Exit installer"

    if [ -x /usr/bin/zenity ]; then

        SELECTION=`/usr/bin/zenity \
                   --width 350 --height 225 \
                   --title "FEniCS Installer" \
                   --text "Welcome to the FEniCS Installer" \
                   --list --radiolist \
                   --column Select \
                   --column Action \
                     True  "${SELECTION1}" \
                     False "${SELECTION2}" \
                     False "${SELECTION3}"`

        case ${SELECTION} in
	    "${SELECTION1}")
                fetch_dorsal
                cfg_dorsal
	        run_dorsal
                ;;
            "${SELECTION2}")
	        PREFIX=`zenity --title 'Select installation path' --file-selection --directory`
                ;;
            "${SELECTION3}")
                cd ${ORIG_DIR}
                exit 0
                ;;
            *)
                echo "default"
                ;;
        esac

    else

        clear
        echo "-------------------------------------------------------------------------------"
        echo "                     Welcome to the FEniCS installer"
        echo "-------------------------------------------------------------------------------"
        echo ""
        echo "          [1] ${SELECTION1}"
        echo "          [2] ${SELECTION2}"
        echo "          [3] ${SELECTION3}"
        echo ""
        echo "-------------------------------------------------------------------------------"
        echo ""
        echo -n "What would you like to do? [1-3]: "
        read OPTION

        case ${OPTION} in
	    1)  fetch_dorsal
                cfg_dorsal
	        run_dorsal
	        ;;
	    2)  echo "Please enter your preferred installation path: ";
	        read PREFIX
	        PREFIX=$(unprettify_dir ${PREFIX})
	        ;;
	    3)  cd ${ORIG_DIR}
	        exit 0
	        ;;
	    *) ;;
        esac
        echo ""

    fi

done
