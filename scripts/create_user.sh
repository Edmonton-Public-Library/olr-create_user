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
#          0.1 - Dev. 
#          0.0 - Dev. 
#
##############################################################################
### This script is run by cron and loads users via either loadflatuser.
## TODO: update to use web services when upgraded on Production. 
##
## The Node.js server will serialize data of users to be created into a file. 
## Find this script and convert to flat user (web service-usable format),
## and load via appropriate mechanism. See create_user.py for conversion functions.
DATE_NOW=$(date +%Y%m%d)                       # Looks like: 20170728
WORK_DIR=/home/ilsadmin/create_user
PY_CONVERTER=$WORK_DIR/scripts/create_user.py
JSON_USERS=$WORK_DIR/incoming/user.data
# FLAT_USERS=$WORK_DIR/incoming/user$DATE_NOW.$$.flat # Production setting.
FLAT_USERS=$WORK_DIR/incoming/user$DATE_NOW.flat      # Test setting.
ERROR=$WORK_DIR/create_user.log
TEST_ILS="sirsi@edpl-t.library.ualberta.ca"  # Test server is default ILS to write to.
PROD_ILS="sirsi@eplapp.library.ualberta.ca"  # Production server is default ILS to write to.
SERVER="$TEST_ILS"                           # Default to test server for customer loading.
LIBRARY="EPLMNA"
TMP_DIR="/tmp"
# SCRATCH=$TMP_DIR/create_user$$.out         # Production setting.
SCRATCH=$WORK_DIR/scripts/create_user.out    # Test setting.
API_SWITCHES="-aU -bU -mc"     # Create user.
USER="ADMIN|PCGUI-DISP"        # Load user for Symphony logging, site specific
VERSION="0.1"

if  [ ! -s "$PY_CONVERTER" ]
then
	printf "** error: can't find associated python conversion script '%s'.\n" $PY_CONVERTER >&2
	echo "internal server error, resource not available."
	exit -1
fi

###############
# Display usage message.
# param:  none
# return: none
usage()
{
	printf "Usage: %s [JSON file]\n" "$0" >&2
	printf " Converts customer accounts from JSON to flat and loads them.\n" >&2
	printf " Version: %s\n" $VERSION >&2
	echo "internal server error. (no params)."
	exit -1
}

[[ -z "$1" ]] && usage
if [ -s "$1" ]; then
	JSON_USERS=$1
	/usr/bin/python3.5 $PY_CONVERTER -j $JSON_USERS >$FLAT_USERS
	if [ -s "$FLAT_USERS" ]; then 
		# Creates a user:
		# Save customer ID for error log.
		echo "loading users: " >>$ERROR
		# Record the ids of the customers that were loaded to the log.
		grep USER_ID "$FLAT_USERS" | awk 'NF>1{print $NF}' | sed -e 's/^..//' >>$ERROR
		count_expected=$(grep USER_ID "$FLAT_USERS" | awk 'NF>1{print $NF}' | sed -e 's/^..//' | wc -l)
		# loadflatuser outputs the new user key to STDOUT if successful.
		cat "$FLAT_USERS" | ssh "$SERVER" 'cat - | loadflatuser -aU -bU -l"ADMIN|PCGUI-DISP" -mc -n -y"EPLMNA" -d' >$SCRATCH
		# For more sophisticated solutions see Metro loaduser.sh.
		## Add a user.
		# loadFlatUserCreate.add("loadflatuser");
		# loadFlatUserCreate.add("-aU"); // Add base.
		# loadFlatUserCreate.add("-bU"); // Add extended.
		# loadFlatUserCreate.add("-l\"ADMIN|PCGUI-DISP\"");
		# loadFlatUserCreate.add("-mc"); // Create
		# loadFlatUserCreate.add("-n"); // Turn off BRS checking if -n is used.
		# loadFlatUserCreate.add("-y\"" + homeLibrary + "\"");
		## loadFlatUserCreate.add("-d"); // write syslog. check Unicorn/Logs/error for results.
		# Update user command.
		# loadFlatUserUpdate = new ArrayList<>();
		# loadFlatUserUpdate.add("loadflatuser");
		# loadFlatUserUpdate.add("-aR"); // replace base information
		# loadFlatUserUpdate.add("-bR"); // Replace extended information
		# loadFlatUserUpdate.add("-l\"ADMIN|PCGUI-DISP\""); // User and station.
		# loadFlatUserUpdate.add("-mu"); // update
		# loadFlatUserUpdate.add("-n"); // turn off BRS checking. // doesn't matter for EPL does matter for Shortgrass.
		# loadFlatUserUpdate.add("-d"); // write syslog. check Unicorn/Logs/error for results.
		count_loaded=$(cat "$SCRATCH" | pipe.pl -gc0:"\d+" | wc -l)
		printf "\$count_loaded='%s' compared with \$count_expected='%s'\n" $count_loaded $count_expected >&2
		if [ "$count_loaded" == "$count_expected" ]; then
			echo "customer successfully loaded."
			rm $SCRATCH                  # Production setting.
			# Don't reload the customer data if it all worked out. However we need to make sure all the customers
			# requested are loaded. The service can accept multiple customers on input.
			rm $JSON_USERS $FLAT_USERS   # Production setting.
			exit 0
		else
			echo "one or more customer load requests failed."
			exit -2
		fi
	else
		echo "*** error failed to convert customer JSON data to flat format." >>$ERROR
		echo "internal server error, conversion error."
		exit -1
	fi
else
	echo "*** error argument file entered on command line is either empty, or was not found." >>$ERROR
	echo "internal server error, no input."
	exit -1
fi


# EOF
