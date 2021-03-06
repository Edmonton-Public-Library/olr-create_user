#!/bin/bash
##################################################################################
#
# Coordinates the conversion from JSON to flat, then loads the flat file(s).
#
# Creates users on the ILS using loadflatuser.
#    Copyright (C) 2020  Andrew Nisbet
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
#          0.11 - Fix echo and remove code to SCP as watcher.js does this now.
#          0.10 - Remove gender.
#          0.9 - Add user to duplicate user database.
#          0.8 - Cut-over for production.
#          0.7 - Added more reporting to log.
#          0.6 -
#          0.5 - Self-standing service conversion.
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
echo "Running $HOME/OnlineRegistration/olr-create-user/scripts/convert_user.sh"
DATE_NOW=$(date '+%Y%m%d%H%M%S')  # Looks like: 20171214164754
WORK_DIR=$HOME/OnlineRegistration/olr-create_user
PY_CONVERTER=$WORK_DIR/scripts/create_user.py
[[ -z "${DEPLOY_ENV}" ]] && DEPLOY_ENV='dev'
if [[ "$DEPLOY_ENV" == "prod" ]]; then
  SERVER=sirsi@edpl.sirsidynix.net
else
  SERVER=sirsi@edpltest.sirsidynix.net
fi
echo "Connecting to $SERVER"

REMOTE_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/OnlineRegistration/Incoming
PY_SCRIPT_DIR=$HOME/OnlineRegistration/olr-duplicate_user/scripts/duplicate_user.py
VERSION="0.11"

if  [ ! -s "$PY_CONVERTER" ]
then
	echo "[$DATE_NOW] ** error: can't find associated python conversion script '$PY_CONVERTER'."  >&2
	echo "[$DATE_NOW] internal server error, resource not available."  >&2
	exit -1
fi
cd $WORK_DIR
if [ -z "$1" ]; then
  echo "[$DATE_NOW] process all files"
  JSON_FILES=$(ls $WORK_DIR/incoming/*.data 2>/dev/null);
else
  echo "[$DATE_NOW] only process $1"
  JSON_FILES=($1)
fi
for json_file in $JSON_FILES; do
  echo "[$DATE_NOW] processing $json_file"
  flat_user_file=$WORK_DIR/incoming/user.$(date '+%Y%m%d%H%M%S%N').flat
	/usr/bin/python3 $PY_CONVERTER -j $json_file >>$flat_user_file
	if [ -s "$flat_user_file" ]; then
		echo "[$DATE_NOW] removing $json_file"
		rm $json_file
	else
		echo "[$DATE_NOW] ** error converting $json_file to $flat_user_file"
	fi
done
# Now if there are any flat files create now or in the past, scp them over.
for flat_file in $(ls $WORK_DIR/incoming/*.flat 2>/dev/null); do
	# move converted user to incoming directory for loading on ILS.
	if scp $flat_file $SERVER:$REMOTE_DIR
	then
		echo "[$DATE_NOW] removing $flat_file after successfully scping to $SERVER:$REMOTE_DIR"		# Once done, add it to the duplicate user database.
		# Before we remove the successful flat file, let's use the data in it to update duplicate user database.
        # UKEY|FNAME|LNAME|BIRTH_DATE|EMAIL|
		# Will convert into the following.
        # 1385638|Bonita|Guler|19740106|bonitas.92@hotmail.com|
		# {"index": {"_id": "1385638"}}
		# {"lname": "Guler", "dob": "1974-01-06", "email": "bonitas.92@hotmail.com", "fname": "Bonita"}
		# This code is taken from sample_users.sh in /software/EDPL/Unicorn/EPLwork/cronjobscripts/OnlineRegistration.
		#
		# Parse out the info we need to make a load-able json file for duplicate_user.py
		# Get the user ids (as keys since they don't have real keys yet on the ILS)|FNAME|LNAME|EMAIL|DOB|
		cat $flat_file | pipe.pl -g'c0:USER_ID|FIRST_NAME|LAST_NAME|BIRTH_DATE|EMAIL' -oc1 -mc1:_# -P -H >$WORK_DIR/tmp.$$
		/usr/bin/python $PY_SCRIPT_DIR -b$WORK_DIR/tmp.$$
		# Even if the above fails, all it means is the duplciate data base doesn't get updated.
		# still remove the flat file, all new customers created since the last time fetch_new_users.sh
		# ran will be added tonight.
		echo "[$DATE_NOW] removing file: " >&2
		rm $flat_file
		rm $WORK_DIR/tmp.$$
	else
		echo "[$DATE_NOW] ** error scp $flat_file"
	fi
done
exit 0
# EOF
