#!/usr/bin/env bash
set -a

#  Copyright (C) 2013-2017 by Uwe Koecher, Bruno Turcksin, Timo Heister,       #
#  the candi authors AND by the DORSAL Authors, cf. AUTHORS file for details.  #
#                                                                              #
#  This file is part of CANDI.                                                 #
#                                                                              #
#  CANDI is free software: you can redistribute it and/or modify               #
#  it under the terms of the GNU Lesser General Public License as              #
#  published by the Free Software Foundation, either                           #
#  version 3 of the License, or (at your option) any later version.            #
#                                                                              #
#  CANDI is distributed in the hope that it will be useful,                    #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU Lesser General Public License for more details.                         #
#                                                                              #
#  You should have received a copy of the GNU Lesser General Public License    #
#  along with CANDI.  If not, see <http://www.gnu.org/licenses/>.              #

#  REMARK: CANDI (Compile & Install) is a majorly tweaked and extended         #
#          software based on DORSAL.                                           #
#  The origin is DORSAL (also licensed under the LGPL):                        #
#          https://bitbucket.org/fenics-project/dorsal/src                     #
#          master c667be2 2013-11-27                                           #

################################################################################
# The Unix date command does not work with nanoseconds, so use
# the GNU date instead. This is available in the 'coreutils' package
# from MacPorts.
if builtin command -v gdate > /dev/null; then
    DATE_CMD=$(which gdate)
else
    DATE_CMD=$(which date)
fi
# Start global timer
TIC_GLOBAL="$(${DATE_CMD} +%s)"

################################################################################
# Parse command line input parameters
PREFIX=~/deal.ii-candi
PROCS=1
CMD_PACKAGES=""
SKIP_READ=false

while [ -n "$1" ]; do
    param="$1"
    case $param in

	-h|--help)
	    echo "candi (Compile & Install)"
	    echo ""
	    echo "Usage: $0 [options]"
	    echo "Options:"
	    echo "  -p <path>, --prefix=<path>  set a different prefix path (default $PREFIX)"
	    echo "  -j <N>, -j<N>, --PROCS=<N>  compile with N processes in parallel (default $PROCS)"
	    echo "  --platform=<platform>       force usage of a particular platform file"
	    echo "  --packages=\"pkg1 pkg2\"      install the given list of packages instead of the default set in candi.cfg"
	    echo "  -y, --yes, --assume-yes     automatic yes to prompts"
	    echo ""
	    echo "The configuration including the choice of packages to install is stored in candi.cfg, see README.md for more information."
	    exit 0
	;;

        #####################################
        # Prefix path
        -p)
	    shift
            PREFIX="${1}"
        ;;
        -p=*|--prefix=*)
            PREFIX="${param#*=}"
            # replace '~' by $HOME
            PREFIX=${PREFIX/#~\//$HOME\/}
        ;;

        #####################################
        # overwrite package list
        --packages=*)
            CMD_PACKAGES="${param#*=}"
        ;;

        #####################################
        # Number of maximum processes to use
        --PROCS=*)
            PROCS="${param#*=}"
        ;;

        # Make styled processes with or without space
	-j)
	    shift
            PROCS="${1}"
	;;

        -j*)
            PROCS="${param#*j}"
        ;;

        #####################################
        # Specific platform
        -pf=*|--platform=*)
            GIVEN_PLATFORM="${param#*=}"
        ;;
        
        #####################################
        # Assume yes to prompts
        -y|--yes|--assume-yes)
            SKIP_READ=true
        ;;

	*)
	    echo "invalid command line option. See -h for more information."
	    exit 1
    esac
    shift
done

# replace '~' by $HOME:
PREFIX_PATH=${PREFIX/#~\//$HOME\/}

RE='^[0-9]+$'
if [[ ! "$PROCS" =~ $RE || $PROCS<1 ]] ; then
  echo "ERROR: invalid number of build processes '$PROCS'"
  exit 1
fi

################################################################################
# Set download tool

# Set given DOWNLOADER as preferred tool
DOWNLOADERS="${DOWNLOADER}"

# Check if the curl download is available
if builtin command -v curl > /dev/null; then
    # Set curl as the prefered download tool, if nothing else is specified
    DOWNLOADERS="${DOWNLOADERS} curl"
fi

# Check if the wget download is available
if builtin command -v wget > /dev/null; then
    # Set wget as the prefered download tool, if nothing else is specified
    DOWNLOADERS="${DOWNLOADERS} wget"
fi

if [ -z "${DOWNLOADERS}" ]; then
    echo "Please install wget or curl."
    exit 1
fi

################################################################################
# Colours for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"
WARN="\033[1;35m"
INFO="\033[1;34m"
BOLD="\033[1m"

################################################################################
# Define candi helper functions

prettify_dir() {
   # Make a directory name more readable by replacing homedir with "~"
   echo ${1/#$HOME\//~\/}
}

cecho() {
    # Display messages in a specified colour
    COL=$1; shift
    echo -e "${COL}$@\033[0m"
}

cls() {
    if [ ${SKIP_READ} = false ]; then
        # clear screen
        COL=$1; shift
        echo -e "${COL}$@\033c"
    fi
}

default () {
    # Export a variable, if it is not already set
    VAR="${1%%=*}"
    VALUE="${1#*=}"
    eval "[[ \$$VAR ]] || export $VAR='$VALUE'"
}

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    STATUS=$?
    if [ ${STATUS} -ne 0 ]; then
        cecho ${BAD} 'Failure with exit status:' ${STATUS}
        cecho ${BAD} 'Exit message:' $1
        exit ${STATUS}
    fi
}

################################################################################
#verify_archive():
#  return -1: internal error
#  return 0: CHECKSUM is matching          (archive found & verified)
#  return 1: No checksum provided          (archive found, but unable to verify)
#  return 2: ARCHIVE_FILE not found        (archive NOT found)
#  return 3: CHECKSUM mismatch             (archive file corrupted)
#  return 4: Neither md5 nor md5sum found  (archive found, but unable to verify)
verify_archive() {
    ARCHIVE_FILE=$1

    # Make sure the archive was downloaded
    if [ ! -e ${ARCHIVE_FILE} ]; then
        return 2
    fi

    # empty file?
    if [ ! -s ${ARCHIVE_FILE} ]; then
        return 2
    fi

    # Check CHECKSUM has been specified for the package
    if [ -z "${CHECKSUM}" ]; then
        cecho ${WARN} "No checksum for ${ARCHIVE_FILE}"
        return 1
    fi

    # Skip verifying archive, if CHECKSUM=ignore
    if [ "${CHECKSUM}" = "ignore" ]; then
        cecho ${WARN} "Skipped checksum check for ${ARCHIVE_FILE}"
        return 1
    fi

    cecho ${INFO} "Verifying ${ARCHIVE_FILE}"

    # Verify CHECKSUM using md5/md5sum
    if builtin command -v md5 > /dev/null; then
	CURRENT="$(md5 -q ${ARCHIVE_FILE})"
    elif builtin command -v md5sum > /dev/null; then
	CURRENT=$(md5sum ${ARCHIVE_FILE} | awk '{print $1}')
    else
        cecho ${BAD} "Neither md5 nor md5sum were found in the PATH"
        return 4
    fi

    for CHECK in ${CHECKSUM}; do
        test "${CHECK}" = "${CURRENT}"
        if [ $? = 0 ]; then
            echo "${ARCHIVE_FILE}: OK"
            return 0
	fi
    done

    cecho ${BAD} "${ARCHIVE_FILE}: FAILED"
    cecho ${BAD} "${CURRENT} does not match any in ${CHECKSUM}"
    return 3
}

download_archive () {
    ARCHIVE_FILE=$1

    # Prepend MIRROR to SOURCE (to prefer) mirror source download
    if [ ! -z "${MIRROR}" ]; then
        SOURCE="${MIRROR} ${SOURCE}"
    fi

    for DOWNLOADER in ${DOWNLOADERS[@]}; do
    for source in ${SOURCE}; do
        # verify_archive:
        # * Skip loop if the ARCHIVE_FILE is already downloaded
        # * Remove corrupted ARCHIVE_FILE
        verify_archive ${ARCHIVE_FILE}
        archive_state=$?

        if [ ${archive_state} = 0 ]; then
             cecho ${INFO} "${ARCHIVE_FILE} already downloaded and verified."
             return 0;

        elif [ ${archive_state} = 1 ] || [ ${archive_state} = 4 ]; then
             cecho ${WARN} "${ARCHIVE_FILE} already downloaded, but unable to be verified."
             return 0;

        elif [ ${archive_state} = 3 ]; then
            cecho ${BAD} "${ARCHIVE_FILE} in your download folder is corrupted"

            # Remove the file and check if that was successful
            rm -f ${ARCHIVE_FILE}
            if [ $? = 0 ]; then
                cecho ${INFO} "Corrupted ${ARCHIVE_FILE} has been removed!"
            else
                cecho ${BAD} "Corrupted ${ARCHIVE_FILE} could not be removed."
                cecho ${INFO} "Please remove the file ${DOWNLOAD_PATH}/${ARCHIVE_FILE} on your own!"
                exit 1;
            fi
        fi
        unset archive_state

        # Set up complete url
        url=${source}${ARCHIVE_FILE}
        cecho ${INFO} "Trying to download ${url}"

        # Download.
        # If curl or wget is failing, continue this loop for trying an other mirror.
        if [ ${DOWNLOADER} = "curl" ]; then
            curl -f -L -k -O ${url} || continue
        elif [ ${DOWNLOADER} = "wget" ]; then
            wget --no-check-certificate ${url} -O ${ARCHIVE_FILE} || continue
        else
            cecho ${BAD} "candi: Unknown downloader: ${DOWNLOADER}"
            exit 1
        fi

        unset url

        # Verify the download
        verify_archive ${ARCHIVE_FILE}
        archive_state=$?
        if [ ${archive_state} = 0 ] || [ ${archive_state} = 1 ] || [ ${archive_state} = 4 ]; then
            # If the download was successful, and the CHECKSUM is matching, ignored, or not possible
            return 0;
        fi
        unset archive_state
    done
    done

    # Unfortunately it seems that (all) download tryouts finally failed for some reason:
    verify_archive ${ARCHIVE_FILE}
    quit_if_fail "Error verifying checksum for ${ARCHIVE_FILE}\nMake sure that you are connected to the internet."
}

package_fetch () {
    cecho ${GOOD} "Fetching ${PACKAGE} ${VERSION}"

    # Fetch the package appropriately from its source
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ] || [ ${PACKING} = ".tar.xz" ] || [ ${PACKING} = ".zip" ]; then
        cd ${DOWNLOAD_PATH}
        download_archive ${NAME}${PACKING}
        quit_if_fail "candi: download_archive ${NAME}${PACKING} failed"

    elif [ ${PACKING} = "git" ]; then
        cd ${UNPACK_PATH}
        # Suitably clone or update git repositories
        if [ ! -d ${EXTRACTSTO} ]; then
            git clone ${SOURCE}${NAME} ${EXTRACTSTO}
            quit_if_fail "candi: git clone ${SOURCE}${NAME} ${EXTRACTSTO} failed"
        else
            cd ${EXTRACTSTO}
            git checkout master --force
            quit_if_fail "candi: git checkout master --force failed"

            git pull
            quit_if_fail "candi: git pull failed"
            cd ..
        fi

        if [ ${STABLE_BUILD} = ON ]; then
            cd ${EXTRACTSTO}
            git checkout ${VERSION} --force
            quit_if_fail "candi: git checkout ${VERSION} --force failed"
            cd ..
        fi

    elif [ ${PACKING} = "hg" ]; then
        cd ${UNPACK_PATH}
        # Suitably clone or update hg repositories
        if [ ! -d ${NAME} ]; then
            hg clone ${SOURCE}${NAME}
        else
            cd ${NAME}
            hg pull --update
            cd ..
        fi
    elif [ ${PACKING} = "svn" ]; then
        cd ${UNPACK_PATH}
        # Suitably check out or update svn repositories
        if [ ! -d ${NAME} ]; then
            svn co ${SOURCE} ${NAME}
        else
            cd ${NAME}
            svn up
            cd ..
        fi
    elif [ ${PACKING} = "bzr" ]; then
        cd ${UNPACK_PATH}
        # Suitably branch or update bzr repositories
        if [ ! -d ${NAME} ]; then
            bzr branch ${SOURCE}${NAME}
        else
            cd ${NAME}
            bzr pull
            cd ..
        fi
    fi

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error fetching ${PACKAGE} ${VERSION} using ${PACKING}."
}

package_unpack() {
    # First make sure we're in the right directory before unpacking
    cd ${UNPACK_PATH}
    FILE_TO_UNPACK=${DOWNLOAD_PATH}/${NAME}${PACKING}

    # Only need to unpack archives
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ] || [ ${PACKING} = ".tar.xz" ] || [ ${PACKING} = ".zip" ]; then
        cecho ${GOOD} "Unpacking ${NAME}${PACKING}"
        # Make sure the archive was downloaded
        if [ ! -e ${FILE_TO_UNPACK} ]; then
            cecho ${BAD} "${FILE_TO_UNPACK} does not exist. Please download first."
            exit 1
        fi

        # remove old unpack (this might be corrupted)
        if [ -d "${EXTRACTSTO}" ]; then
            rm -rf ${EXTRACTSTO}
            quit_if_fail "Removing of ${EXTRACTSTO} failed."
        fi

        # Unpack the archive only if it isn't already

        # Unpack the archive in accordance with its packing
        if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tbz2" ]; then
            tar xjf ${FILE_TO_UNPACK}
        elif [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tgz" ]; then
            tar xzf ${FILE_TO_UNPACK}
        elif [ ${PACKING} = ".tar.xz" ]; then
            tar xJf ${FILE_TO_UNPACK}
        elif [ ${PACKING} = ".zip" ]; then
            unzip ${FILE_TO_UNPACK}
        fi
    fi

    # Apply patches with git cherry-pick of commits given by ${CHERRYPICKCOMMITS}
    if [ ${PACKING} = "git" ] && [ ! -z "${CHERRYPICKCOMMITS}" ]; then
        cecho ${INFO} "candi: git cherry-pick -X theirs ${CHERRYPICKCOMMITS}"
        cd ${UNPACK_PATH}/${EXTRACTSTO}
        git cherry-pick -X theirs ${CHERRYPICKCOMMITS}
        quit_if_fail "candi: git cherry-pick -X theirs ${CHERRYPICKCOMMITS} failed"
    fi

    # Apply patches
    cd ${UNPACK_PATH}/${EXTRACTSTO}
    package_specific_patch

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error unpacking ${FILE_TO_UNPACK}."

    unset FILE_TO_UNPACK
}

package_build() {
    # Get things ready for the compilation process
    cecho ${GOOD} "Building ${PACKAGE} ${VERSION}"

    if [ ! -d "${UNPACK_PATH}/${EXTRACTSTO}" ]; then
        cecho ${BAD} "${EXTRACTSTO} does not exist -- please unpack first."
        exit 1
    fi

    # Set the BUILDDIR if nothing else was specified
    default BUILDDIR=${BUILD_PATH}/${NAME}

    # Clean the build directory if specified
    if [ -d ${BUILDDIR} ] && [ ${CLEAN_BUILD} = ON ]; then
        rm -rf ${BUILDDIR}
    fi

    # Create build directory if it does not exist
    if [ ! -d ${BUILDDIR} ]; then
        mkdir -p ${BUILDDIR}
    fi

    # Move to the build directory
    cd ${BUILDDIR}

    # Carry out any package-specific setup
    package_specific_setup
    quit_if_fail "There was a problem in build setup for ${PACKAGE} ${VERSION}."
    cd ${BUILDDIR}

    # Use the appropriate build system to compile and install the
    # package
    for cmd_file in candi_configure candi_build; do
        echo "#!/usr/bin/env bash" >${cmd_file}
        chmod a+x ${cmd_file}

        # Write variables to files so that they can be run stand-alone
        declare -x| grep -v "!::"| grep -v "ProgramFiles(x86)" >>${cmd_file}

        # From this point in candi_*, errors are fatal
        echo "set -e" >>${cmd_file}
    done

    if [ ${BUILDCHAIN} = "autotools" ]; then
        if [ -f ${UNPACK_PATH}/${EXTRACTSTO}/configure ]; then
            echo ${UNPACK_PATH}/${EXTRACTSTO}/configure ${CONFOPTS} --prefix=${INSTALL_PATH} >>candi_configure
        fi

        for target in "${TARGETS[@]}"; do
            echo make ${MAKEOPTS} -j ${PROCS} $target >>candi_build
        done

    elif [ ${BUILDCHAIN} = "cmake" ]; then
        rm -f ${BUILDDDIR}/CMakeCache.txt
        rm -rf ${BUILDDIR}/CMakeFiles
        echo cmake ${CONFOPTS} -DCMAKE_INSTALL_PREFIX=${INSTALL_PATH} ${UNPACK_PATH}/${EXTRACTSTO} >>candi_configure
        for target in "${TARGETS[@]}"; do
            echo make ${MAKEOPTS} -j ${PROCS} $target >>candi_build
        done

    elif [ ${BUILDCHAIN} = "python" ]; then
        echo cp -rf ${UNPACK_PATH}/${EXTRACTSTO}/* . >>candi_configure
        echo ${PYTHON_INTERPRETER} setup.py install --prefix=${INSTALL_PATH} >>candi_build

    elif [ ${BUILDCHAIN} = "scons" ]; then
        echo cp -rf ${UNPACK_PATH}/${EXTRACTSTO}/* . >>candi_configure
        for target in "${TARGETS[@]}"; do
            echo scons -j ${PROCS} ${CONFOPTS} prefix=${INSTALL_PATH} $target >>candi_build
        done

    elif [ ${BUILDCHAIN} = "custom" ]; then
        # Write the function definition to file
        declare -f package_specific_build >>candi_build
        echo package_specific_build >>candi_build

    elif [ ${BUILDCHAIN} = "ignore" ]; then
        cecho ${INFO} "Info: ${PACKAGE} has forced BUILDCHAIN=${BUILDCHAIN}."

    else
        cecho ${BAD} "candi: internal error: BUILDCHAIN=${BUILDCHAIN} for ${PACKAGE} unknown."
        exit 1
    fi
    echo "touch candi_successful_build" >> candi_build

    # Run the generated build scripts
    if [ ${BASH_VERSINFO} -ge 3 ]; then
        set -o pipefail
        ./candi_configure 2>&1 | tee candi_configure.log
    else
        ./candi_configure
    fi
    quit_if_fail "There was a problem configuring ${PACKAGE} ${VERSION}."

    if [ ${BASH_VERSINFO} -ge 3 ]; then
        set -o pipefail
        ./candi_build 2>&1 | tee candi_build.log
    else
        ./candi_build
    fi
    quit_if_fail "There was a problem building ${PACKAGE} ${VERSION}."

    # Carry out any package-specific post-build instructions
    package_specific_install
    quit_if_fail "There was a problem in post-build instructions for ${PACKAGE} ${VERSION}."
}

package_register() {
    # Set any package-specific environment variables
    package_specific_register
    quit_if_fail "There was a problem setting environment variables for ${PACKAGE} ${VERSION}."
}

package_conf() {
    # Write any package-specific environment variables to a config file,
    # i.e. e.g. a modulefile or source-able *.conf file
    package_specific_conf
    quit_if_fail "There was a problem creating the configfiles for ${PACKAGE} ${VERSION}."
}

guess_platform() {
    # Try to guess the name of the platform we're running on
    if [ -f /usr/bin/cygwin1.dll ]; then
        echo cygwin

    elif [ -x /usr/bin/sw_vers ]; then
        local MACOSVER=$(sw_vers -productVersion)
        case ${MACOSVER} in
            10.11*)  echo elcapitan;;
            10.12*)  echo sierra;;
            10.13*)  echo highsierra;;
            10.14*)  echo mojave;;
            10.15*)  echo catalina;;
        esac

    elif [ ! -z "$CRAYOS_VERSION" ]; then
        echo cray

    elif [ -f /etc/os-release ]; then
        local OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
        local OS_VERSIONID=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
        local OS_MAJOR_VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' | grep -oE '[0-9]+' | head -n 1)
        local OS_NAME=$(grep -oP '(?<=^NAME=).+' /etc/os-release | tr -d '"')
        local OS_PRETTY_NAME=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')

        if [ "$OS_ID" == "fedora" ]; then
            echo fedora${OS_VERSIONID}

        elif [ "$OS_ID" == "centos" ]; then
            echo centos${OS_VERSIONID}

        elif [ "$OS_ID" == "rhel" ]; then
            echo rhel${OS_MAJOR_VER}

        elif [ "$OS_ID" == "debian" ]; then
            echo debian${OS_MAJOR_VER}

        elif [ "$OS_ID" == "ubuntu" ]; then
            echo ubuntu${OS_MAJOR_VER}

        elif [ "$OS_ID" == "opensuse" ]; then
            if [ "${OS_NAME}" == "openSUSE Leap" ]; then
                echo opensuse15
            fi

        elif [ "${PRETTY_NAME}" == "Arch Linux" ]; then
            echo arch

        elif [ "${PRETTY_NAME}" == "Manjaro Linux" ]; then
            echo arch
        fi
    fi
}

guess_ostype() {
    # Try to guess the operating system type (ostype)
    if [ -f /usr/bin/cygwin1.dll ]; then
        echo cygwin

    elif [ -x /usr/bin/sw_vers ]; then
        echo macos

    elif [ -x /etc/os-release ]; then
        echo linux
    fi
}

guess_architecture() {
    # Try to guess the architecture of the platform we are running on
    ARCH=unknown
    if [ -x /usr/bin/uname -o -x /bin/uname ]
    then
        ARCH=`uname -m`
    fi
}

################################################################################
### candi script
################################################################################

cls
echo "*******************************************************************************"
cecho ${GOOD} "This is candi (compile and install)"
echo

# Keep the current work directory of candi.sh
# WARNING: You should NEVER override this variable!
export ORIG_DIR=`pwd`

################################################################################
# Read configuration variables from candi.cfg
source candi.cfg

# For changes specific to your local setup or for debugging, use local.cfg
if [ -f local.cfg ]; then
    source local.cfg
fi

# If any variables are missing, set them to defaults
default PROJECT=deal.II-toolchain

default DOWNLOAD_PATH=${PREFIX_PATH}/tmp/src
default UNPACK_PATH=${PREFIX_PATH}/tmp/unpack
default BUILD_PATH=${PREFIX_PATH}/tmp/build
default INSTALL_PATH=${PREFIX_PATH}
default CONFIGURATION_PATH=${INSTALL_PATH}/configuration

default CLEAN_BUILD=OFF
default STABLE_BUILD=ON
default DEVELOPER_MODE=OFF

default PACKAGES_OFF=""

if [ -n "$CMD_PACKAGES" ]; then
    PACKAGES=$CMD_PACKAGES
fi

################################################################################
# Check if project was specified correctly
if [ -d ${PROJECT} ]; then
    if [ -d ${PROJECT}/platforms -a -d ${PROJECT}/packages ]; then
        cecho ${INFO} "Project: ${PROJECT}: Found configuration."
    else
        cecho ${BAD} "Please contact the authors, if you have not changed candi!"
        cecho ${INFO} "candi: Internal error:"
        cecho ${INFO} "No subdirectories 'platforms' and 'packages' in ${PROJECT}."
        exit 1
    fi
else
    cecho ${BAD} "Please contact the authors, if you have not changed candi!"
    cecho ${INFO} "candi: Internal error:"
    cecho ${INFO} "Error: No project configuration directory found for project ${PROJECT}."
    echo "Please check if you have specified right project name in candi.cfg"
    echo "Please check if you have directory called ${PROJECT}"
    echo "with subdirectories ${PROJECT}/platforms and ${PROJECT}/packages"
    exit 1
fi

################################################################################
# Operating system (PLATFORM) check
if [ -z "${GIVEN_PLATFORM}" ]; then
    # No platform is forced to use, try to find a platform file.
    PLATFORM_SUPPORTED=${PROJECT}/platforms/supported/`guess_platform`.platform
    PLATFORM_CONTRIBUTED=${PROJECT}/platforms/contributed/`guess_platform`.platform
    PLATFORM_DEPRECATED=${PROJECT}/platforms/deprecated/`guess_platform`.platform

    if [ -e ${PLATFORM_SUPPORTED} ]; then
        PLATFORM=${PLATFORM_SUPPORTED}
        cecho ${INFO} "using ./${PLATFORM}."

    elif [ -e ${PLATFORM_CONTRIBUTED} ]; then
        PLATFORM=${PLATFORM_CONTRIBUTED}
        cecho ${INFO} "using ./${PLATFORM}."
        cecho ${WARN} "Warning: Platform is not officially supported but may still work!"

    elif [ -e ${PLATFORM_DEPRECATED} ]; then
        PLATFORM=${PLATFORM_DEPRECATED}
        cecho ${INFO} "using ./${PLATFORM}."
        cecho ${WARN} "Warning: Platform is deprecated and will be removed shortly but may still work!"

    else
        cecho ${BAD} "Error: Your operating system could not be automatically recognised."
        echo "You may force a (similar) platform directly by:"
        echo "./candi.sh --platform=${PROJECT}/platforms/ {supported|contributed|deprecated} / <FORCED>.platform"
        exit 1
    fi

    unset PLATFORM_SUPPORTED
    unset PLATFORM_CONTRIBUTED
    unset PLATFORM_DEPRECATED

else
    # Forced platform by the user, check if the given platform file is available.
    if [ -e ${GIVEN_PLATFORM} ]; then
        PLATFORM=${GIVEN_PLATFORM}
        cecho ${BAD} "using (user-forced) ./${PLATFORM}."

        unset GIVEN_PLATFORM

    else
        cecho ${BAD} "Error: Your forced platform file ${GIVEN_PLATFORM} does not exists"
        exit 1
    fi
fi
echo

# Guess the operating system type -> PLATFORM_OSTYPE
PLATFORM_OSTYPE=`guess_ostype`
if [ -z "${PLATFORM_OSTYPE}" ]; then
    cecho ${WARN} "WARNING: could not determine your Operating System Type (assuming linux)"
    PLATFORM_OSTYPE=linux
fi

cecho ${INFO} "Operating System Type detected as: ${PLATFORM_OSTYPE}"

if [ -z "${PLATFORM_OSTYPE}" ]; then
    # check if PLATFORM_OSTYPE is set and not empty failed
    cecho ${BAD} "Error: (internal) could not set PLATFORM_OSTYPE"
	exit 1
fi

# Guess dynamic shared library file extension -> LDSUFFIX
if [ ${PLATFORM_OSTYPE} == "linux" ]; then
    LDSUFFIX=so

elif [ ${PLATFORM_OSTYPE} == "macos" ]; then
    LDSUFFIX=dylib

elif [ ${PLATFORM_OSTYPE} == "cygwin" ]; then
    LDSUFFIX=dll
fi

cecho ${INFO} "Dynamic shared library file extension detected as: *.${LDSUFFIX}"

if [ -z "${LDSUFFIX}" ]; then
    # check if PLATFORM_OSTYPE is set and not empty failed
    cecho ${BAD} "Error: (internal) could not set LDSUFFIX"
	exit 1
fi

# Source default PACKAGES variables, if none were given so far
if [ -z "${PACKAGES}" ]; then
    DEFAULT_PACKAGES=${PROJECT}/packages/default.packages
    if [ -e ${DEFAULT_PACKAGES} ]; then
        source ${DEFAULT_PACKAGES}
    fi
fi

# Source PLATFORM variables if set up correctly
if [ -z ${PLATFORM} ]; then
    cecho ${BAD} "Please contact the authors, if you have not changed candi!"
    cecho ${INFO} "candi: Internal error, no PLATFORM variable available."
    exit 1
else
    # Load PLATFORM variables
    source ${PLATFORM}
fi
echo

# Output PLATFORM details
echo "-------------------------------------------------------------------------------"
cecho ${WARN} "Please read carefully your operating system notes below!"
echo

# Show the initial comments in the platform file until the pattern '##' appears.
# Further, removes first field '#' before the output.
awk '/^##/ {exit} {$1=""; print}' <${PLATFORM}
echo

# Let the user confirm now, that the PLATFORM is set up correctly
echo "-------------------------------------------------------------------------------"
if [ ${SKIP_READ} = false ]; then
    cecho ${GOOD} "Please make sure you've read the instructions above and your system"
    cecho ${GOOD} "is ready for installing ${PROJECT}."
    cecho ${BAD} "If not, please abort the installer by pressing <CTRL> + <C> !"
    cecho ${INFO} "Then copy and paste these instructions into this terminal."
    echo

    cecho ${GOOD} "Once ready, hit enter to continue!"
    read
fi

################################################################################
# Output configuration details
cls
echo "*******************************************************************************"
cecho ${GOOD} "candi tries now to download, configure, build and install:"
echo
cecho ${GOOD} "Project:  ${PROJECT}"
cecho ${GOOD} "Platform: ${PLATFORM}"
echo
echo "-------------------------------------------------------------------------------"

if [ ${DEVELOPER_MODE} = "OFF" ]; then
    cecho ${INFO} "Downloading files to:     $(prettify_dir ${DOWNLOAD_PATH})"
    cecho ${INFO} "Unpacking files to:       $(prettify_dir ${UNPACK_PATH})"
elif [ ${DEVELOPER_MODE} = "ON" ]; then
    cecho ${BAD} "Warning: You are using the DEVELOPER_MODE"
    cecho ${INFO} "Note: You need to have run candi with the same settings without this mode before!"
    cecho ${BAD} "For packages not in the build mode={load|skip|once}, candi now use"
    cecho ${BAD} "source files from: $(prettify_dir ${UNPACK_PATH})"
    echo
else
    cecho ${BAD} "candi: bad variable: DEVELOPER_MODE={ON|OFF}; (your specified option is = ${DEVELOPER_MODE})"
    exit 1
fi

cecho ${INFO} "Building packages in:     $(prettify_dir ${BUILD_PATH})"
cecho ${GOOD} "Installing packages in:   $(prettify_dir ${INSTALL_PATH})"
cecho ${GOOD} "Package configuration in: $(prettify_dir ${CONFIGURATION_PATH})"
echo

echo "-------------------------------------------------------------------------------"
cecho ${INFO} "Number of (at most) build processes to use: PROCS=${PROCS}"
echo

echo "-------------------------------------------------------------------------------"
cecho ${INFO} "Packages:"
for PACKAGE in ${PACKAGES[@]}; do
    echo ${PACKAGE}
done
echo


echo "-------------------------------------------------------------------------------"
if [ ${STABLE_BUILD} = ON ]; then
    cecho ${INFO} "Building stable releases of ${PROJECT} packages."
else
    cecho ${WARN} "Building development versions of ${PROJECT} packages."
fi
echo

# if the program 'module' is available, output the currently loaded modulefiles
if builtin command -v module > /dev/null; then
    echo "-------------------------------------------------------------------------------"
    cecho ${GOOD} Currently loaded modulefiles:
    cecho ${INFO} "$(module list)"
    echo
fi

############################################################################
# Compiler variables check
echo "Compiler Variables:"
# Firstly test, if compiler variables are set,
#   and if not try to set the default mpi-compiler suite
# finally test, if compiler variables are useful.

echo "-------------------------------------------------------------------------------"

# CC test
if [ ! -n "$CC" ]; then
    if builtin command -v mpicc > /dev/null; then
        cecho ${WARN} "CC variable not set, but default mpicc found."
        export CC=mpicc
    fi
fi

if [ -n "$CC" ]; then
    cecho ${INFO} "CC  = $(which $CC)"
else
    cecho ${BAD} "CC  variable not set. Please set it with $ export CC  = <(MPI) C compiler>"
fi

# CXX test
if [ ! -n "$CXX" ]; then
    if builtin command -v mpicxx > /dev/null; then
        cecho ${WARN} "CXX variable not set, but default mpicxx found."
        export CXX=mpicxx
    fi
fi

if [ -n "$CXX" ]; then
    cecho ${INFO} "CXX = $(which $CXX)"
else
    cecho ${BAD} "CXX variable not set. Please set it with $ export CXX = <(MPI) C++ compiler>"
fi

# FC test
if [ ! -n "$FC" ]; then
    if builtin command -v mpif90 > /dev/null; then
        cecho ${WARN} "FC variable not set, but default mpif90 found."
        export FC=mpif90
    fi
fi

if [ -n "$FC" ]; then
    cecho ${INFO} "FC  = $(which $FC)"
else
    cecho ${BAD} "FC  variable not set. Please set it with $ export FC  = <(MPI) Fortran 90 compiler>"
fi

# FF test
if [ ! -n "$FF" ]; then
    if builtin command -v mpif77 > /dev/null; then
        cecho ${WARN} "FF variable not set, but default mpif77 found."
        export FF=mpif77
    fi
fi

if [ -n "$FF" ]; then
    cecho ${INFO} "FF  = $(which $FF)"
else
    cecho ${BAD} "FF  variable not set. Please set it with $ export FF  = <(MPI) Fortran 77 compiler>"
fi
echo

# Final test for compiler variables
if [ -z "$CC" ] || [ -z "$CXX" ] || [ -z "$FC" ] || [ -z "$FF" ]; then
    cecho ${WARN} "One or multiple compiler variables (CC,CXX,FC,FF) are not set."
    cecho ${INFO} "Please read your platform information above carefully,"
    cecho ${INFO} "  how you get those compilers installed and set up!"
    cecho ${INFO} "Usually the values should be: mpicc, mpicxx, mpif90 and mpif77."
    cecho ${WARN} "It is strongly recommended to set them to guarantee the same compilers for all dependencies."
    echo
fi

################################################################################
# Force the user to accept the current output
echo "-------------------------------------------------------------------------------"
if [ ${SKIP_READ} = false ]; then
    cecho ${GOOD} "Once ready, hit enter to continue!"
    read
fi

################################################################################
# Output configuration details
cls
echo "*******************************************************************************"
cecho ${GOOD} "candi tries now to download, configure, build and install:"
echo
cecho ${GOOD} "Project:  ${PROJECT}"
cecho ${GOOD} "Platform: ${PLATFORM}"
echo


# Figure out what binary to use for python support. Note that older PETSc ./configure only supports python2. For now, prefer
# using python2 but use what the user supplies as PYTHON_INTERPRETER.
if builtin command -v python2 --version > /dev/null; then
  default PYTHON_INTERPRETER="python2"
fi
if builtin command -v python2.7 --version > /dev/null; then
  default PYTHON_INTERPRETER="python2.7"
fi
if builtin command -v python3 --version > /dev/null; then
  default PYTHON_INTERPRETER="python3"
fi
default PYTHON_INTERPRETER="python"

# Figure out the version of the existing python:
default PYTHONVER=`${PYTHON_INTERPRETER} -c "import sys; print(sys.version[:3])"`

# Create necessary directories and set appropriate variables
mkdir -p ${DOWNLOAD_PATH}
mkdir -p ${UNPACK_PATH}
mkdir -p ${BUILD_PATH}
mkdir -p ${INSTALL_PATH}
mkdir -p ${CONFIGURATION_PATH}

# configuration script
cat > ${CONFIGURATION_PATH}/enable.sh <<"EOF"
#!/bin/bash
# helper script to source all configuration files. Use
#    source enable.sh
# to load into your current shell.

# find path of script:
pushd . >/dev/null
P="${BASH_SOURCE[0]}";cd `dirname $P`;P=`pwd`;
popd >/dev/null

for f in $P/*
do
  if [ "$f" != "$P/enable.sh" ] && [ -f "$f" ]
  then
    source $f
  fi
done
EOF


# Keep original variables
# WARNING: do not overwrite this variables!
ORIG_INSTALL_PATH=${INSTALL_PATH}
ORIG_CONFIGURATION_PATH=${CONFIGURATION_PATH}
ORIG_PROCS=${PROCS}

guess_architecture

# Reset timings
TIMINGS=""

# Fetch and build individual packages
for PACKAGE in ${PACKAGES[@]}; do
    # Start timer
    TIC="$(${DATE_CMD} +%s)"

    # Return to the original CANDI directory
    cd ${ORIG_DIR}

    # Skip building this package if the user requests it
    SKIP=false
    case ${PACKAGE} in
        load:*) SKIP=true; LOAD=true; PACKAGE=${PACKAGE#*:};;
        skip:*) SKIP=true;  PACKAGE=${PACKAGE#*:};;
        once:*)
          # If the package is turned off in the deal.II configuration, do not
          # install it.
          PACKAGE=${PACKAGE#*:};
          if [[ ${PACKAGES_OFF} =~ ${PACKAGE} ]]; then
            SKIP=true;
          else
            SKIP=maybe;
          fi;;
    esac

    # Check if the package exists
    if [ ! -e ${PROJECT}/packages/${PACKAGE}.package ]; then
        cecho ${BAD} "${PROJECT}/packages/${PACKAGE}.package does not exist yet. Please create it."
        exit 1
    fi

    # Reset package-specific variables
    unset NAME
    unset VERSION
    unset SOURCE
    unset PACKING
    unset EXTRACTSTO
    unset CHECKSUM
    unset BUILDCHAIN
    unset BUILDDIR
    unset CONFOPTS
    unset MAKEOPTS
    unset CONFIG_FILE
    unset CHERRYPICKCOMMITS
    TARGETS=('' install)
    PROCS=${ORIG_PROCS}
    INSTALL_PATH=${ORIG_INSTALL_PATH}
    CONFIGURATION_PATH=${ORIG_CONFIGURATION_PATH}

    # Reset package-specific functions
    package_specific_patch () { true; }
    package_specific_setup () { true; }
    package_specific_build () { true; }
    package_specific_install () { true; }
    package_specific_register () { true; }
    package_specific_conf() { true; }

    # Fetch information pertinent to the package
    source ${PROJECT}/packages/${PACKAGE}.package

    # Turn to a stable version of the package if that's what the user
    # wants and it exists
    if [ ${STABLE_BUILD} = ON ] && [ -e ${PROJECT}/packages/${PACKAGE}-stable.package ]; then
        source ${PROJECT}/packages/${PACKAGE}-stable.package
    fi

    # Ensure that the package file is sanely constructed
    if [ ! "${BUILDCHAIN}" ]; then
        cecho ${BAD} "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
        exit 1
    fi

    if [ ! "${BUILDCHAIN}" = "ignore" ] ; then
        if [ ! "${NAME}" ] || [ ! "${SOURCE}" ] || [ ! "${PACKING}" ]; then
            cecho ${BAD} "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
            exit 1
        fi
    fi

    # Most packages extract to a directory named after the package
    default EXTRACTSTO=${NAME}

    # Check if the package can be set to SKIP:
    default BUILDDIR=${BUILD_PATH}/${NAME}
    if [ ${SKIP} = maybe ] && [ ! -f ${BUILDDIR}/candi_successful_build ]; then
        SKIP=false
    fi

    # Fetch, unpack and build package
    if [ ${SKIP} = false ]; then
        if [ ${DEVELOPER_MODE} = "OFF" ]; then
            # Fetch, unpack and build the current package
            package_fetch
            package_unpack
        fi
        package_build
    else
        if [ ! -z "${LOAD}" ]; then
            # Let the user know we're loading the current package
            cecho ${GOOD} "Loading ${PACKAGE}"
            unset LOAD
        else
            # Let the user know we're skipping the current package
            cecho ${GOOD} "Skipping ${PACKAGE}"
        fi
    fi
    package_register
    package_conf

    # Store timing
    TOC="$(($(${DATE_CMD} +%s)-TIC))"
    TIMINGS="$TIMINGS"$"\n""$PACKAGE: ""$((TOC)) s"
done

# print information about enable.sh
echo
echo To export environment variables for all installed libraries execute:
echo
cecho ${GOOD} "    source ${CONFIGURATION_PATH}/enable.sh"
echo

# Stop global timer
TOC_GLOBAL="$(($(${DATE_CMD} +%s)-TIC_GLOBAL))"

# Display a summary
echo
cecho ${GOOD} "Build finished in $((TOC_GLOBAL)) seconds."
echo
echo "Summary of timings:"
echo -e "$TIMINGS"
