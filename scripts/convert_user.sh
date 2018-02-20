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
DATE_NOW=$(date '+%Y%m%d%H%M%S')  # Looks like: 20171214164754
WORK_DIR=/home/ilsadmin/create_user
PY_CONVERTER=$WORK_DIR/scripts/create_user.py
JSON_TO_FLAT_USER=$WORK_DIR/incoming/user.$DATE_NOW.flat
LOG=$WORK_DIR/create_user.log
TEST_ILS="sirsi@edpl-t.library.ualberta.ca"  # Test server is default ILS to write to.
PROD_ILS="sirsi@eplapp.library.ualberta.ca"  # Production server is default ILS to write to.
SERVER="$PROD_ILS"                           # Current server target.
REMOTE_DIR=/s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration/Incoming
VERSION="0.8"

if  [ ! -s "$PY_CONVERTER" ]
then
	echo "** error: can't find associated python conversion script '$PY_CONVERTER'."  >&2
	echo "internal server error, resource not available."  >&2
	exit -1
fi
cd $WORK_DIR
for json_file in $(ls $WORK_DIR/incoming/*.data 2>/dev/null); do
	/usr/bin/python3.5 $PY_CONVERTER -j $json_file 2>>$LOG >>$JSON_TO_FLAT_USER 
	if [ -s "$JSON_TO_FLAT_USER" ]; then 
		echo "removing $json_file" >>$LOG
		rm $json_file
	else
		echo "** error converting $json_file to $JSON_TO_FLAT_USER" >>$LOG
	fi
done
# Now if there are any flat files create now or in the past, scp them over.
for flat_file in $(ls $WORK_DIR/incoming/*.flat 2>/dev/null); do
	# move converted user to incoming directory for loading on ILS.
	if scp $flat_file $SERVER:$REMOTE_DIR >>$LOG
	then
		echo "removing $flat_file after successfully scping to $SERVER:$REMOTE_DIR" >>$LOG
		rm $flat_file
	else
		echo "** error scp $flat_file" >>$LOG
	fi
done
exit 0
# EOF
