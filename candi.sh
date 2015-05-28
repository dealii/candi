#!/usr/bin/env bash
set -a

#  Copyright (C) 2013-2014 by Uwe Koecher                                      #
#  AND by the DORSAL Authors, cf. the file AUTHORS for details                 #
#                                                                              #
#  This file is part of CANDI.                                                 #
#                                                                              #
#  CANDI is free software: you can redistribute it and/or modify               #
#  it under the terms of the GNU Lesser General Public License as              #
#  published by the Free Software Foundation, either                           #
#  version 2.1 of the License, or (at your option) any later version.          #
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

# The Unix date command does not work with nanoseconds, so use
# the GNU date instead. This is available in the 'coreutils' package
# from MacPorts.
if builtin command -v gdate > /dev/null; then
    DATE_CMD=$(which gdate)
else
    DATE_CMD=$(which date)
fi

# Start global timer
TIC_GLOBAL="$(${DATE_CMD} +%s%N)"

# Colours for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"
WARN="\033[1;34m"
BOLD="\033[1m"

### Define helper functions ###

prettify_dir() {
   # Make a directory name more readable by replacing homedir with "~"
   echo ${1/#$HOME\//~\/}
}

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

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    STATUS=$?
    if [ ${STATUS} -ne 0 ]; then
        cecho ${BAD} 'Failure with exit status:' ${STATUS}
        cecho ${BAD} 'Exit message:' $1
        exit ${STATUS}
    fi
}

package_fetch () {
    # First, make sure we're in the right directory before downloading
    cd ${DOWNLOAD_PATH}

    cecho ${GOOD} "Fetching ${NAME}"

    # Fetch the package appropriately from its source
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ] || [ ${PACKING} = ".tar.xz" ] || [ ${PACKING} = ".zip" ]; then
        # Only download archives that do not exist
        if [ ! -e ${NAME}${PACKING} ]; then
            if [ ${STABLE_BUILD} = false ] && [ ${USE_SNAPSHOTS} = true ]; then
                wget --retry-connrefused --no-check-certificate --server-response -c ${SOURCE}${NAME}${PACKING} -O ${NAME}${PACKING}
            else
                wget --retry-connrefused --no-check-certificate -c ${SOURCE}${NAME}${PACKING} -O ${NAME}${PACKING}
            fi
        fi

        # Download again when using snapshots and unstable packages, but
        # only when the timestamp has changed
        if [ ${STABLE_BUILD} = false ] && [ ${USE_SNAPSHOTS} = true ]; then
            wget --timestamping --retry-connrefused --no-check-certificate ${SOURCE}${NAME}${PACKING}
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
    elif [ ${PACKING} = "git" ]; then
        cd ${UNPACK_PATH}
        # Suitably clone or update git repositories
        if [ ! -d ${EXTRACTSTO} ]; then
            git clone ${SOURCE}${NAME} ${EXTRACTSTO}
        else
            cd ${EXTRACTSTO}
            git pull
            cd ..
        fi
        if [ ${STABLE_BUILD} = true ] && [${VERSION} != "git"]; then
            cd ${EXTRACTSTO}
            git checkout ${VERSION}
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
    quit_if_fail "Error fetching ${NAME}."
}

package_verify() {
    # First make sure we're in the right directory before verifying checksum
    cd ${DOWNLOAD_PATH}

    # Only need to verify archives
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] ||  [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ] || [ ${PACKING} = ".tar.xz" ] || [ ${PACKING} = ".zip" ]; then
        cecho ${GOOD} "Verifying ${NAME}${PACKING}"
      
        # Check checksum has been specified for the package
        if [ -z "${CHECKSUM}" ]; then
            cecho ${WARN} "No checksum for ${NAME}${PACKING}"
            return 1
        fi
        
        # Skip checksum if asked to ignore
        if [ "${CHECKSUM}" = "ignore" ]; then
            cecho ${WARN} "Skipped checksum check for ${NAME}${PACKING}"
            return 1
        fi
        
        # Make sure the archive was downloaded
        if [ ! -e ${NAME}${PACKING} ]; then
            cecho ${BAD} "${NAME}${PACKING} does not exist. Please download first."
            exit 1
        fi
        
        # Verify checksum using md5/md5sum
        if builtin command -v md5 > /dev/null; then
            test "${CHECKSUM}" = "$(md5 -q ${NAME}${PACKING})" && echo "${NAME}${PACKING}: OK"
        elif builtin command -v md5sum > /dev/null; then
            echo "${CHECKSUM}  ${NAME}${PACKING}" | md5sum --check -
        else
            cecho ${BAD} "Neither md5 nor md5sum were found in the PATH"
            return 1
        fi
    fi
    
    # Quit with a useful message if something goes wrong
    quit_if_fail "Error verifying checksum for ${NAME}${PACKING}\nMake sure that you are connected to the internet.\nIf a corrupted file has been downloaded, please remove\n   ${DOWNLOAD_PATH}/${NAME}${PACKING}\nbefore you restart candi!"
}


package_unpack() {
    # First make sure we're in the right directory before unpacking
    cd ${UNPACK_PATH}
    FILE_TO_UNPACK=${DOWNLOAD_PATH}/${NAME}${PACKING}

    # Only need to unpack archives
    if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tbz2" ] || [ ${PACKING} = ".tgz" ] || [ ${PACKING} = ".tar.xz" ] || [ ${PACKING} = ".zip" ]; then
        cecho ${GOOD} "Unpacking ${NAME}"
        # Make sure the archive was downloaded
        if [ ! -e ${FILE_TO_UNPACK} ]; then
            cecho ${BAD} "${FILE_TO_UNPACK} does not exist. Please download first."
            exit 1
        fi

        # Unpack the archive only if it isn't already or when using
        # snapshots and unstable packages
        if [ ${STABLE_BUILD} = false ] && [ ${USE_SNAPSHOTS} = true ] || [ ! -d "${EXTRACTSTO}" ]; then
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
    fi

    unset FILE_TO_UNPACK

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error unpacking ${NAME}."
}

package_build() {
    # Get things ready for the compilation process
    cecho ${GOOD} "Building ${NAME}"
    if [ ! -d "${EXTRACTSTO}" ]; then
        cecho ${BAD} "${EXTRACTSTO} does not exist -- please unpack first."
        exit 1
    fi

    # Set the BUILDDIR if nothing else was specified
    default BUILDDIR=${BUILD_PATH}/${NAME}

    # Clean the build directory if specified
    if [ -d ${BUILDDIR} ] && [ ${CLEAN_BUILD} = "true" ]; then
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
    cd ${BUILDDIR}
    quit_if_fail "There was a problem in build setup for ${NAME}."

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
    elif [ ${BUILDCHAIN} = "python" ]; then
        echo cp -rf ${UNPACK_PATH}/${EXTRACTSTO}/* . >>candi_configure
        echo python setup.py install --prefix=${INSTALL_PATH} >>candi_build
    elif [ ${BUILDCHAIN} = "scons" ]; then
        echo cp -rf ${UNPACK_PATH}/${EXTRACTSTO}/* . >>candi_configure
        for target in "${TARGETS[@]}"; do
            echo scons -j ${PROCS} ${SCONSOPTS} prefix=${INSTALL_PATH} $target >>candi_build
        done
    elif [ ${BUILDCHAIN} = "cmake" ]; then
        echo cmake ${CONFOPTS} -DCMAKE_INSTALL_PREFIX=${INSTALL_PATH} ${UNPACK_PATH}/${EXTRACTSTO} >>candi_configure
        for target in "${TARGETS[@]}"; do
            echo make ${MAKEOPTS} -j ${PROCS} $target >>candi_build
        done
#        for target in "${TARGETS[@]}"; do
#            echo make -C ${BUILDDIR} ${MAKEOPTS} -j ${PROCS} $target >>candi_build
#        done
    elif [ ${BUILDCHAIN} = "custom" ]; then
        # Write the function definition to file
        declare -f package_specific_build >>candi_build
        echo package_specific_build >>candi_build
    fi
    echo "touch candi_successful_build" >> candi_build

    # Run the generated build scripts
    if [ ${BASH_VERSINFO} -ge 3 ]; then
        set -o pipefail
        ./candi_configure 2>&1 | tee candi_configure.log
    else
        ./candi_configure
    fi
    quit_if_fail "There was a problem configuring ${NAME}."

    if [ ${BASH_VERSINFO} -ge 3 ]; then
        set -o pipefail
        ./candi_build 2>&1 | tee candi_build.log
    else
        ./candi_build
    fi
    quit_if_fail "There was a problem building ${NAME}."

    # Carry out any package-specific post-build instructions
    package_specific_install
    quit_if_fail "There was a problem in post-build instructions for ${NAME}."
}

package_register() {
    # Set any package-specific environment variables
    package_specific_register
    quit_if_fail "There was a problem setting environment variables for ${NAME}."
}

package_conf() {
    # Write any package-specific environment variables to a config file,
    # i.e. e.g. a modulefile or source-able *.conf file
    package_specific_conf
    quit_if_fail "There was a problem creating the configfiles for ${NAME}."
}

guess_platform() {
    # Try to guess the name of the platform we're running on
    if [ -f /usr/bin/cygwin1.dll ]
    then
        echo cygwin
    elif [ -f /etc/fedora-release ]
    then
        local FEDORANAME=`gawk '{if (match($0,/\((.*)\)/,f)) print f[1]}' /etc/fedora-release`
        case ${FEDORANAME} in
            "Schrödinger’s Cat"*) echo fedora19;;
            "Heisenbug"*)         echo fedora20;;
            "Twenty One"*)        echo fedora21;;
            "Twenty Two"*)        echo fedora22;;
        esac
    elif [ -f /etc/redhat-release ]
    then
        local RHELNAME=`gawk '{if (match($0,/\((.*)\)/,f)) print f[1]}' /etc/redhat-release`
        case ${RHELNAME} in
            "Tikanga"*) echo rhel5;;
            "Santiago"*) echo rhel6;;
            "Maipo"*) echo rhel7;;
            "Core"*) echo centos7;;
        esac
    elif [ -x /usr/bin/sw_vers ]
    then
        local MACOSVER=$(sw_vers -productVersion)
        case ${MACOSVER} in
            10.4*)    echo tiger;;
            10.5*)    echo leopard;;
            10.6*)    echo snowleopard;;
            10.7*)    echo lion;;
            10.8*)    echo mountainlion;;
    esac
    elif [ -x /usr/bin/lsb_release ]; then
        local DISTRO=$(lsb_release -i -s)
        local CODENAME=$(lsb_release -c -s)
        local DESCRIPTION=$(lsb_release -d -s)
        case ${DISTRO}:${CODENAME}:${DESCRIPTION} in
            *:*:*Ubuntu*\ 13*)     echo ubuntu13;;
            *:*:*Ubuntu*\ 14*)     echo ubuntu14;;
            *:Tikanga*:*)          echo rhel5;;
            *:Santiago*:*)         echo rhel6;;
            Scientific:Carbon*:*)  echo rhel6;;
            *:*:*CentOS*\ 5*)      echo rhel5;;
            *:*:*CentOS*\ 6*)      echo rhel6;;
            *:*:*openSUSE\ 12*)    echo opensuse12;;
            *:*:*openSUSE\ 13*)    echo opensuse13;;
        esac
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

###############################################################################
# Start the build process

export ORIG_DIR=`pwd`

# Read configuration variables from candi.cfg
source candi.cfg

# For changes specific to your local setup or for debugging, use local.cfg
if [ -f local.cfg ]; then
    source local.cfg
fi

# If any variables are missing, revert them to defaults
default PROJECT=deal.II
default DOWNLOAD_PATH=${HOME}/apps/candi/${PROJECT}/src
default UNPACK_PATH=${HOME}/apps/candi/${PROJECT}/unpack
default BUILD_PATH=${HOME}/apps/candi/${PROJECT}/build
default CLEAN_BUILD=false
default INSTALL_PATH=${HOME}/apps/candi/${PROJECT}
default PROCS=1
default STABLE_BUILD=true
default USE_SNAPSHOTS=false

# Check if project was specified correctly
if [ -d ${PROJECT} ]; then
    if [ -d ${PROJECT}/platforms -a -d ${PROJECT}/packages ]; then
        cecho ${GOOD} "Found configuration for project ${PROJECT}."
    else
        cecho ${BAD} "No subdirectories 'platforms' and 'packages' in ${PROJECT}."
        echo "Please make sure there exists proper project configuration directory."
        exit 1
    fi
else
    cecho ${BAD} "Error: No project configuration directory found for project ${PROJECT}."
    echo "Please check if you have specified right project name in candi.cfg"
    echo "Please check if you have directory called ${PROJECT}"
    echo "with subdirectories ${PROJECT}/platforms and ${PROJECT}/packages"
    exit 1
fi

# Check if candi.sh was invoked correctly
if [ $# -eq 0 ]; then
    PLATFORM_SUPPORTED=${PROJECT}/platforms/supported/`guess_platform`.platform
    PLATFORM_CONTRIBUTED=${PROJECT}/platforms/contributed/`guess_platform`.platform
    PLATFORM_DEPRECATED=${PROJECT}/platforms/deprecated/`guess_platform`.platform
    if [ -e ${PLATFORM_SUPPORTED} ]; then
        PLATFORM=${PLATFORM_SUPPORTED}
        cecho ${GOOD} "Building ${PROJECT} using ${PLATFORM}."
    elif [ -e ${PLATFORM_CONTRIBUTED} ]; then
        PLATFORM=${PLATFORM_CONTRIBUTED}
        cecho ${GOOD} "Building ${PROJECT} using ${PLATFORM}."
        cecho ${BOLD} "Warning: Platform is not officially supported but may still work!"
    elif [ -e ${PLATFORM_DEPRECATED} ]; then
        PLATFORM=${PLATFORM_DEPRECATED}
        cecho ${GOOD} "Building ${PROJECT} using ${PLATFORM}."
        cecho ${BAD} "Warning: Platform is deprecated and will be removed shortly but may still work!"
    else
	cecho ${BAD} "Error: Platform to build for not specified (and not automatically recognised)."
	echo "If you know the platform you are interested in (myplatform), please specify it directly, as:"
	echo "./candi.sh ${PROJECT}/platforms/myplatform.platform"
	echo "If you'd like to learn more, refer to the file USAGE for detailed usage instructions."
	exit 1
    fi
    echo "-------------------------------------------------------------------------------"
    # Show the initial comments in the platform file, as it often
    # contains instructions about packages that should be installed
    # first, etc. Remove first field '#' so that cut-and-paste of
    # e.g. apt-get commands is easy.
    awk '/^##/ {exit} {$1=""; print}' <${PLATFORM}
    echo
    echo "Downloading files to:   $(prettify_dir ${DOWNLOAD_PATH})"
    echo "Unpacking files to:     $(prettify_dir ${UNPACK_PATH})"
    echo "Building projects in:   $(prettify_dir ${BUILD_PATH})"
    echo "Installing projects in: $(prettify_dir ${INSTALL_PATH})"
    echo
    if [ ${STABLE_BUILD} = true ]; then
        echo "Building stable point-releases of ${PROJECT} projects."
    else
        if [ ${USE_SNAPSHOTS} = true ]; then
	    echo "Building development versions of ${PROJECT} projects (using snapshots)."
        else
            echo "Building development versions of ${PROJECT} projects."
        fi
    fi
    echo "-------------------------------------------------------------------------------"
    cecho ${GOOD} "Please make sure you've read the instructions above and your system"
    cecho ${GOOD} "is ready for installing ${PROJECT}. We find it easiest to copy and paste"
    cecho ${GOOD} "these instructions in another terminal window."

    if builtin command -v module > /dev/null; then
        echo ""
        echo "-------------------------------------------------------------------------------"
        cecho ${GOOD} "$(module list)"
        echo "-------------------------------------------------------------------------------"
    fi

    echo "-------------------------------------------------------------------------------"
    echo "Compiler Variables:"
    if [ -n "$CC" ]; then
        cecho ${WARN} "CC  = $(which $CC)"
    else
        cecho ${BAD} "CC  variable not set. Please set it with $ export CC  = <(MPI) C compiler>"
    fi

    if [ -n "$CXX" ]; then
        cecho ${WARN} "CXX = $(which $CXX)"
    else
        cecho ${BAD} "CXX variable not set. Please set it with $ export CXX = <(MPI) C++ compiler>"
    fi

    if [ -n "$FC" ]; then
        cecho ${WARN} "FC  = $(which $FC)"
    else
        cecho ${BAD} "FC  variable not set. Please set it with $ export FC  = <(MPI) Fortran 90 compiler>"
    fi

    if [ -n "$FF" ]; then
        cecho ${WARN} "FF  = $(which $FF)"
    else
        cecho ${BAD} "FF  variable not set. Please set it with $ export FF  = <(MPI) Fortran 77 compiler>"
    fi
    
    if [ -z "$CC" ] || [ -z "$CXX" ] || [ -z "$FC" ] || [ -z "$FF" ]; then
        cecho ${WARN} "One or multiple compiler variables (CC,CXX,FC,FF) are not set."
        cecho ${BAD} "Usually, mpicc, mpicxx, mpif90 and mpif77 should be the values."
        cecho ${WARN} "It is strongly recommended to set them to guarantee the same compilers for all dependencies."
    fi
    echo "-------------------------------------------------------------------------------"
    
    echo ""
    cecho ${GOOD} "Once ready, hit enter to continue!"
    read
elif [ $# -eq 1 ]; then
    PLATFORM=${1}
elif [ $# -eq 2 ]; then
    # Check if the user wants to install a single package
    if [ ${1} == "install-package" ]; then
        PACKAGE=${2}
        # Check if the package exists
        if [ ! -e ${PROJECT}/packages/${PACKAGE}.package ]; then
            cecho ${BAD} "${PROJECT}/packages/${PACKAGE}.package does not exist yet. Please create it."
            exit 1
        fi
        PACKAGES=(${PACKAGE})
        PLATFORM="${PROJECT}/platforms/.single"
    else
        echo "If you'd like to install a single package, please use the syntax:"
        echo "./candi.sh install-package foo"
        exit 1
    fi
fi

# Make sure the requested platform exists
if [ -e "${PLATFORM}" ]; then
    source ${PLATFORM}
else
    cecho ${BAD} "Platform set '${PLATFORM}' not found. Refer to the file README to check if your platform is supported."
    exit 1
fi

# If the platform doesn't override the system python by installing its
# own, figure out the version of the existing python
default PYTHONVER=`python -c "import sys; print sys.version[:3]"`

# Create necessary directories and set appropriate variables
mkdir -p ${DOWNLOAD_PATH}
mkdir -p ${UNPACK_PATH}
mkdir -p ${BUILD_PATH}
mkdir -p ${INSTALL_PATH}

ORIG_INSTALL_PATH=${INSTALL_PATH}
ORIG_PROCS=${PROCS}
guess_architecture

# Reset timings
TIMINGS=""

# Fetch and build individual packages
for PACKAGE in ${PACKAGES[@]}; do
    # Start timer
    TIC="$(${DATE_CMD} +%s%N)"
    
    # Return to the main CANDI directory
    cd ${ORIG_DIR}
    
    # Skip building this package if the user requests it
    SKIP=false
    case ${PACKAGE} in
        skip:*) SKIP=true;  PACKAGE=${PACKAGE#*:};;
        once:*) SKIP=maybe; PACKAGE=${PACKAGE#*:};;
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
    unset SCONSOPTS
    unset CONFIG_FILE
    TARGETS=('' install)
    PROCS=${ORIG_PROCS}
    INSTALL_PATH=${ORIG_INSTALL_PATH}
    
    # Reset package-specific functions
    package_specific_setup () { true; }
    package_specific_build () { true; }
    package_specific_install () { true; }
    package_specific_register () { true; }
    package_specific_conf() { true; }

    # Fetch information pertinent to the package
    source ${PROJECT}/packages/${PACKAGE}.package
    
    # Turn to a stable version of the package if that's what the user
    # wants and it exists
    if [ ${STABLE_BUILD} = true ] && [ -e ${PROJECT}/packages/${PACKAGE}-stable.package ]; then
        source ${PROJECT}/packages/${PACKAGE}-stable.package
    elif [ ${STABLE_BUILD} = false ] && [ ${USE_SNAPSHOTS} = true ] && [ -e ${PROJECT}/packages/${PACKAGE}-snapshot.package ]; then
        source ${PROJECT}/packages/${PACKAGE}-snapshot.package
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

    if [ ${SKIP} = maybe ] && [ ! -f ${BUILD_PATH}/${NAME}/candi_successful_build ]; then
        SKIP=false
    fi
    
    # Fetch, unpack and build package
    if [ ${SKIP} = false ]; then
        # Fetch, unpack and build the current package
        package_fetch
        package_verify
        package_unpack
        package_build
    else
        # Let the user know we're skipping the current package
        cecho ${GOOD} "Skipping ${NAME}"
    fi
    package_register
    package_conf
    
    # Store timing
    TOC="$(($(${DATE_CMD} +%s%N)-TIC))"
    TIMINGS="$TIMINGS"$"\n""$PACKAGE: ""$((TOC/1000000000)) s"
done

# Stop global timer
TOC_GLOBAL="$(($(${DATE_CMD} +%s%N)-TIC_GLOBAL))"

# Display a summary
echo
cecho ${GOOD} "Build finished in $((TOC_GLOBAL/1000000000)) seconds."
echo
echo "Summary of timings:"
echo -e "$TIMINGS"

