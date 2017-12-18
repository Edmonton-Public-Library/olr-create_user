#!/bin/bash
##################################################################################
#
# Coordinates the conversion from JSON to flat, then loads the flat file(s). 
#
# Creates users on the ILS using loadflatuser.
#    Copyright (C) 2017  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Copyright (c) Thu Feb 23 16:22:30 MST 2017
# Rev: 
#          0.4 - Fix ssh load. 
#          0.3 - Fixing stuff so the script can run it. 
#          0.2 - Dereference path variable fix. 
#          0.1 - Dev. 
#          0.0 - Dev. 
#
##############################################################################
### This script is run by create_user.js Node.js application. It converts JSON
### formatted customer information into FLAT customer information, then moves 
### the FLAT customer to the $CREATE_USER/incoming directory to be loaded by 
### load_flat_user.sh.
##
## The Node.js server will serialize data of users to be created into a file. 
## Find this script and convert to flat user (web service-usable format),
## and load via appropriate mechanism. See create_user.py for conversion functions.
DATE_NOW=$(date +%Y%m%d%H%M%S)  # Looks like: 20171214164754
WORK_DIR=/home/ilsadmin/create_user
PY_CONVERTER=${WORK_DIR}/scripts/create_user.py
JSON_TO_FLAT_USER=${WORK_DIR}/user.$$.flat
LOAD_DIR=${WORK_DIR}/incoming
ERROR=${WORK_DIR}/create_user.$$.err
CHECK=${WORK_DIR}/create_user.$$.out    # Test setting.
VERSION="0.3"

if  [ ! -s "$PY_CONVERTER" ]
then
	echo "** error: can't find associated python conversion script '$PY_CONVERTER'."  >&2
	echo "internal server error, resource not available."
	exit -1
fi

###############
# Display usage message.
# param:  none
# return: none
usage()
{
	echo "Usage: $0 [JSON file]" >&2
	echo " Converts customer accounts from JSON to FLAT and loads them." >&2
	echo " Version: $VERSION"  >&2
	exit 1
}

[[ -z "$1" ]] && usage
if [ -s "$1" ]; then
	JSON_USERS=${1}
	/usr/bin/python3.5 ${PY_CONVERTER} -j ${JSON_USERS} >${JSON_TO_FLAT_USER} # 2>>${ERROR}
	if [ -s "$JSON_TO_FLAT_USER" ]; then 
		# move converted user to incoming directory for loading.
		scp ${JSON_TO_FLAT_USER} sirsi\@edpl-t.library.ualberta.ca:/s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration/Incoming
	else
		echo "*** error failed to convert customer JSON data to FLAT format." >>${ERROR}
		echo "internal server error, conversion error."
		exit 2
	fi
else
	echo "*** error argument file entered on command line is either empty, or was not found." >>${ERROR}
	echo "internal server error, no input."
	exit 1
fi
exit 0
# EOF
