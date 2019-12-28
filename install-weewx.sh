#!/bin/bash
#
# flexible installer for weewx in Simulator mode for Debian(ish) systems
#
# uncomment the desired lines below to pick your installation
# method and version.  This is tested on debian 10.0 (Raspbian)
# on a pi4, so your mileage may vary slightly on older debian.
#
# specifically, debian 10.0 provides pyephem for both python2
# and python3 in dpkg format.  Previously you sometimes needed
# to use pip to install this.  Pip is supported if you want to
# use that method for pyephem.  See below for details
#
# Caveats:
#    weewx < 4.0 requires python2 only
#

#-------------------------------------------------------------
# START EDITING HERE
#-------------------------------------------------------------

#---
#--- uncomment to set debug=1 in weewx.conf
#---
DEBUG_MODE=1

#---
#--- uncomment only one of these to install pyephem (optional)
#---
# INSTALL_PYEPHEM_METHOD="pip"
INSTALL_PYEPHEM_METHOD="dpkg"

#---
#---  uncomment only one of these
#---
# PYTHON_VERSION=2
PYTHON_VERSION=3

#---
#--- uncomment one of the following sections
#--- and define your desired version if applicable
#---
#--- if you try to download a version that is no longer there
#--- the download will abort and display the URL to check to
#--- see if there is a newer 'current' version present
#---

## use the current dpkg version
# WEEWX_DOWNLOAD_METHOD="dpkg"
# WEEWX_VERSION="not_applicable"                 # ignored if uncommented

## setup.py main git repo
# WEEWX_DOWNLOAD_METHOD="git"
# WEEWX_VERSION="not_applicable"                 # ignored if uncommented
# WEEWX_GIT_BRANCH="master"                      # mandatory (typically 'master' or 'development')

## setup.py released tgz
# WEEWX_DOWNLOAD_METHOD="released"
# WEEWX_VERSION="3.9.2"                          # mandatory

## setup.py toplevel tgz
# WEEWX_DOWNLOAD_METHOD="current"
# WEEWX_VERSION="3.9.2"                          # mandatory

## setup.py development_versions tgz
WEEWX_DOWNLOAD_METHOD="development_versions" 
WEEWX_VERSION="4.0.0b5"                          # mandatory

#-------------------------------------------------------------
# STOP EDITING HERE
#-------------------------------------------------------------

case "x${PYTHON_VERSION}" in
"x2")
    PIP="/usr/bin/pip2"
    PYTHON="/usr/bin/python2"
    ;;
"x3")
    PIP="/usr/bin/pip3"
    PYTHON="/usr/bin/python3"
    ;;
*)
    echo ""
    echo "ERROR - unknown PYTHON_VERSION"
    echo ""
    exit 1
esac

#--- start of functions ---

# make sure the prerequisites are there before proceeding
function install_weewx_prerequisites () {

    # learn the upstream repo contents
    sudo apt-get update -y
    
    # uncomment to update everything to current
    #   - commented out here to speed up my dev/test cycle
    #     but you almost certainly 'do' want to upgrade
    #     on your system of course
    #
    # sudo apt-get upgrade
    
    # get ancillary stuff not always in the vagrant base box
    sudo apt-get install -y sqlite3 lynx wget curl procps nginx ntp git

    # prerequisite python packages, some perhaps a little optional
    case "${PYTHON_VERSION}" in
    "2")
        PYTHON_PACKAGES="python-minimal python-pil python-configobj python-serial python-usb python-dev python-cheetah python-pip"
        PYEPHEM_PACKAGE="python-ephem"
        ;;
    "3")
        PYTHON_PACKAGES="python3-minimal python3-pil python3-configobj python3-serial python3-usb python3-dev python3-cheetah python3-pip"
        PYEPHEM_PACKAGE="python3-ephem"
        ;;
    esac

    # ok install'em
    sudo apt-get install -y ${PYTHON_PACKAGES} 
    
    # optional - this will slow your install down a bit
    #            due to dependencies
    #
    case "x{INSTALL_PYEPHEM_METHOD}" in
	"xpip")
        sudo ${PIP} install pyephem
        ;;
    "xdpkg")
        sudo apt-get install -y ${PYEPHEM_PACKAGE}
        ;;
    esac

}

#-------------------------------------------------------------

# download and extract the tarball to a predictable place
function prepare_for_setup_py () {
    wget -q ${URL_ROOT}/weewx-${WEEWX_VERSION}.tar.gz -O /tmp/weewx.tgz
    retcode=$?
    if [ "x${retcode}" != "x0" ]
    then
        echo ""
        echo "ERROR: failure downloading weewx from ${URL_ROOT} - check your version variable"
        echo ""
        exit 1
    fi
    echo "...extracting weewx..."
    cd /tmp
    tar zxf /tmp/weewx.tgz
}

#-------------------------------------------------------------

# run python setup.py, salt to taste, then start weewx up
function setup_and_start () {
    echo "...building weewx (simulator mode)..."
    cd /tmp/weewx-${WEEWX_VERSION}
    retcode=$?
    if [ "x${retcode}" != "x0" ]
    then
        echo ""
        echo "ERROR - can't cd to /tmp/weewx-${WEEWX_VERSION} - check your download worked"
        echo ""
        exit 1
    fi
    ${PYTHON} ./setup.py build
    sudo ${PYTHON} ./setup.py install --no-prompt

    # link it into the web at the top of the docroot
    echo "...symlink to top of web docroot..."
    sudo  ln -s /var/www/html /home/weewx/public_html

    # put system startup file into place
    echo "...hook weewx into systemd..."
    sudo cp /home/weewx/util/systemd/weewx.service /etc/systemd/system
    sudo systemctl enable weewx

    # set debug mode on
    if [ "x${DEBUG_MODE}" = "x1" ]
    then
        sudo sed -i 's:debug = 0:debug = 1:' /home/weewx/weewx.conf
    fi

    # set the location to something indicating this os
    HOSTNAME=`hostname`
    sudo sed -i -e s:Hood\ River,\ Oregon:${HOSTNAME}: /home/weewx/weewx.conf
    sudo sed -i -e s:My\ Little\ Town,\ Oregon:${HOSTNAME}: /home/weewx/weewx.conf

    # light that candle
    echo "...starting weewx..."
    sudo systemctl start weewx
}

#-------------------------------------------------------
# main() below here
#-------------------------------------------------------

# install everything we'll need
# (this can take a while)
install_weewx_prerequisites

case "x${WEEWX_DOWNLOAD_METHOD}" in

   "xdpkg")

        echo "...run the latest released dpkg version..."

        #--- define weewx repo for apt ---
        echo "...defining weewx repo..."
        wget -qO - http://weewx.com/keys.html      | sudo apt-key add -
        wget -qO - http://weewx.com/apt/weewx.list | sudo tee /etc/apt/sources.list.d/weewx.list
        apt-get update

        #--- install weewx in simulator mode with no prompts ---
        echo "...installing  weewx..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y weewx

        # link it into the web at the top of the docroot
        echo "...symlink to top of web docroot..."
        sudo  ln -s /var/www/html /var/www/html/weewx

        # set the location to something indicating this os
        HOSTNAME=`hostname`
        sed -i -e s:Santa\'s\ Workshop\,\ North\ Pole:${HOSTNAME}: /etc/weewx/weewx.conf
        sed -i -e s:My\ Little\ Town,\ Oregon:${HOSTNAME}: /home/weewx/weewx.conf

        # set debug mode on
        if [ "x${DEBUG_MODE}" = "x1" ]
        then
            sudo sed -i 's:debug = 0:debug = 1:' /etc/weewx/weewx.conf
            sudo systemctl restart weewx
        fi

        ;;

     "xreleased")

        echo "...downloading released version ${WEEWX_VERSION}..."
        URL_ROOT="http://www.weewx.com/downloads/released_versions"
        prepare_for_setup_py
        setup_and_start

        ;;

     "xdevelopment_versions")

        echo "...downloading development version ${WEEWX_VERSION}..."
        URL_ROOT="http://www.weewx.com/downloads/development_versions"
        prepare_for_setup_py
        setup_and_start

        ;;

     "xcurrent")

        echo "...downloading current ${WEEWX_VERSION}..."
        URL_ROOT="http://www.weewx.com/downloads"
        prepare_for_setup_py
        setup_and_start

        ;;

   "xgit")

        # this is a little kludgy, but we set things setup_and_start require otherwise
        WEEWX_VERSION="current"                   # bogus value for user feedback only
        WEEWX_GIT_TARGET="/tmp/weewx-current"     # this is hard-coded for setup_and_start

        echo "...cloning the latest git repo..."
        WEEWX_GIT_URL="https://github.com/weewx/weewx.git"
        git clone ${WEEWX_GIT_URL} ${WEEWX_GIT_TARGET}
        cd ${WEEWX_GIT_TARGET}
	git checkout ${WEEWX_GIT_BRANCH}
	cd -

        setup_and_start
        ;;

      *)

        echo ""
        echo "...ERROR - please set your WEEWX_DOWNLOAD_METHOD to a known value..."
        echo ""
        exit 1

        ;;

esac

#-------------------------------------
# that's all folks
#-------------------------------------
