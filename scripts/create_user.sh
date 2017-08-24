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
FLAT_USERS=$WORK_DIR/incoming/user$DATE_NOW.$$.flat
SSH_SERVER="sirsi@edpl-t.library.ualberta.ca"  # Test server is default ILS to write to.
USER="ADMIN|PCGUI-DISP"
LIBRARY="EPLMNA"
TMP_DIR="/tmp"
VERSION="0.1"


if  [ ! -s "$PY_CONVERTER" ]
then
	printf "** error: can't find associated python conversion script '%s'.\n" $PY_CONVERTER >&2
	exit 99
fi

###############
# Display usage message.
# param:  none
# return: none
usage()
{
	printf "Usage: %s [-option]\n" "$0" >&2
	printf " Converts customer accounts from JSON to flat and loads them.\n" >&2
	printf " Order of options matter. For example if you want to write to Test ILS\n" >&2
	printf " you need to run with '-t' as the first option. Example: $0 -t [-other_options].\n" >&2
	printf "   -j<json_file> - Converts file from JSON to flat.\n" >&2
	printf "   -l<flat_file> - Loads the flat file to \$SSH_SERVER (currently $SSH_SERVER).\n" >&2
	printf "   -L<json_file> - Like '-l', but does both conversion from JSON then loads flat.\n" >&2
	printf "   -p - Write users to Production ILS server not Test ILS.\n" >&2
	printf "   Version: %s\n" $VERSION >&2
	exit 1
}

# Tests if a user exists in the ILS.
# param:  flat file of user information. File must exist prior to calling.
# return: 1 if the user has an account with that user id, and 0 if they don't.
user_not_exist()
{
	local flat="$1"
	local user_id=$(grep USER_ID "$flat" | awk 'NF>1{print $NF}' | sed -e 's/^..//')
	# If we failed to grab the user id, then return 1, which means they exist, the
	# caller will likely try to update the account which will fail if it doesn't exist
	# which in this case is what we want.
	if [ -z "$user_id" ]; then
		printf "** error couldn't read the user's id from the file '%s'\n" "$flat" >&2
		return 2
	fi
	local tmp_file="$TMP_DIR/tmp.$$"
	# sshpass -p"YOUR PASSWORD" ssh -t -t "$SSH_SERVER" << EOSSH >$tmp_file
	ssh -t -t "$SSH_SERVER" << EOSSH >$tmp_file
echo "$user_id" | seluser -iB
exit
EOSSH
	grep "error number 111" "$tmp_file" 2>&1 > /dev/null
	local status=$?
	rm "$tmp_file"
	echo $status
}

# Loads customer data from file and executes it via SSH adding variables as
# required.
# param:  flat file of customer data.
# return: 0 if everything went well and 1 otherwise.
load_customer()
{
	if [ -z "$1" ]; then
		printf "*** error empty file name argument.\n" >&2
		return
	fi
	# TODO: Add check if this is a load or an update.
	local user_test=$(user_not_exist "$1")
	# API to use, default is to update. If there's a problem we just output file name.
	# Will return the number of lines, characters and words in the flat on error.
	local API="wc" 
	if [ -z "$user_test" ]; then
		printf "** error, caller didn't return. Is the process hung?\n" >&2
		return 1
	elif [ "$user_test" -eq 2 ]; then
		printf "** error, failed to parse input file, is it a flat file?\n" >&2
		return 1
	elif [ "$user_test" -eq 1 ]; then
		printf "user exists marking for update.\n" >&2
		# Create the user.
		API="loadflatuser -aR -bR -mu -n -y$LIBRARY"
	elif [ "$user_test" -eq 0 ]; then
		printf "loading user.\n" >&2
		# Update customer
		API="loadflatuser -aU -bU -mc -n -y$LIBRARY"
	else
		printf "** error, can't determine if this is an update or create.\n" >&2
		mv "$1" "$1.fail" # Save the file as a fail file for admin to check and load later.
		return 1
	fi
	# Add a trailing '\' to each line - except the last - in this way we can echo all the flat data from one variable.
	local customer=$(cat "$1" | sed -e '$ ! s/$/\\/')
	# sshpass -p"YOUR PASSWORD" ssh -t -t "$SSH_SERVER" << EOSSH >$tmp_file
	ssh -t -t "$SSH_SERVER" << EOSSH
echo "$customer" | $API -l"$USER"
exit
EOSSH
}  # The output is interpreted by the caller (ME server).

# Converts argument JSON file to flat file.
# param:  JSON file.
# return: 0 if conversion successful, and 1 otherwise.
JSON_to_flat()
{
	[[ -z "$1" ]] && echo "**error, empty file passed as argument." >&2
	if [ ! -s "$1" ]; then
		printf "**error, argument file '%s' does not exist or is empty.\n" "$1" >&2
		return 1
	fi
	return 0
}

# Loads the argument flat file into the ILS.
# param:  fully qualified path to the flat file. 
# return: 0 if successful and 1 otherwise.
load_flat_file()
{
	flat_file=$1
	if [ -s "$1" ]; then
		result=$(load_customer "$flat_file")
		if [ -z "$result" ]; then
			printf "*** error occured while loading customer account.\n" >&2
		else
			printf "%s\n" "$result"
			return 0
		fi
	else
		printf "*** error argument entered is either empty, not a file, or the file was not found.\n" >&2
	fi
	return 1
}

############################## Taken from ME Libraries' loaduser.sh

while getopts ":j:l:L:px" opt; do
  case $opt in
	j)	if [ ! JSON_to_flat "$OPTARG" ]; then
			printf "JSON conversion failed. Check files and locations and try again.\n" >&2
			exit 1
		else
			printf "JSON conversion completed successfully.\n" >&2
			exit 0
		fi
		;;
	l)  printf "-l selected, whith argument '%s'\n." "$OPTARG" >&2
		;;
	L)  printf "-L selected, but not implemented yet.\n" "$OPTARG" >&2
		;;
	p)  printf "-t selected, loading customers to Test ILS.\n" >&2
		SSH_SERVER="sirsi@eplapp.library.ualberta.ca"  # Test system at EPL.
		;;
	x)	usage
		exit 1
		;;
	\?)	printf "Invalid option: -$OPTARG \n" >&2
		usage
		exit 1
		;;
	:)	printf "Option -$OPTARG requires an argument.\n" >&2
		usage
		exit 1
		;;
  esac
done
# EOF
