#!/bin/bash
##################################################################################
#
# Loads online registration customers.
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
#
#          0.2 - Save flat information loaded for reference checks.
#          0.1 - Cut-over version for production.
#          0.0 - Dev.
#
##############################################################################
### Checks the Incoming directory and loads any flat files it finds.
. /software/EDPL/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
################################################################
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')
ANSI_DATE=$(date '+%Y%m%d')
WORK_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/OnlineRegistration
FLAT_LOADED_SO_FAR=$WORK_DIR/loaded_users.flat
cd $WORK_DIR
if [ -z "$1" ]; then
  echo "process all files"
  FLAT_FILES=$(ls $WORK_DIR/Incoming/*.flat 2>/dev/null);
else
  echo "only process $1"
  FLAT_FILES="$1"
fi
for flat_customer in $FLAT_FILES; do
	retain_flat_file=0
    id=$(date '+%Y%m%d%H%M%S%N')
    output_result=$WORK_DIR/load_user_$id.txt
    output_key=$WORK_DIR/load_user_$id.keys
	echo "[$DATE_NOW] loading $flat_customer"
	for user_id in $(cat $flat_customer | pipe.pl -gc0:USER_ID -oc1 -mc1:_#); do
		echo "[$DATE_NOW] attempt load $user_id"
	done
	# The line below loads the customer data, and may need to be adapted if
	# the website submits customer information with a preferred library.
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
	# loadFlatUserUpdate.add("-n"); // turn off BRS checking.
    # Note: Symphony 3.5.1 the -m flag's default will create if the account doesn't exists
    # and update if it does. The question is, does it create if the flat file is a brief record
    # and testing on May 9, 2019 shows that the account doesn't exist, a new one is NOT created
    # if you use a brief record. It fails with '**User NAME missing.' error. This is good since
    # we don't want empty accounts created from brief records. However if the account does exist
    # the -mb (default) causes the account, and only the fields in the brief record, to be updated.
    # From this experiment I modify the below command to remove the -m flag all together.
    ## Create if account doesn't exist and flat file is not a brief record, update otherwise.
    cat $flat_customer | loadflatuser -aU -bU -l"ADMIN|PCGUI-DISP" -n -y"EPLMNA" -d 2>>$output_result >>$output_key
	## Create
	# cat $flat_customer | loadflatuser -aU -bU -l"ADMIN|PCGUI-DISP" -mc -n -y"EPLMNA" -d 2>>$output_result >>$output_key
	## Update
	# cat $flat_customer | loadflatuser -aR -bR -l"ADMIN|PCGUI-DISP" -mu -n -y"EPLMNA" -d 2>$output_result >$output_key
	for line in $(grep "error number 111" $output_result 2>/dev/null); do
		retain_flat_file=1
		echo "[$DATE_NOW] failed load: $line"
	done
	status=$(grep 1402 $output_result 2>/dev/null)
    #  1 $<new> $<user> $(1402) ## if customer is created or new user.
    #  0 $<new> $<user> $(1419) ## if customer already exists.
	echo "[$DATE_NOW] status '$status'"
	if [ "$retain_flat_file" ] && [ ! -z "$status" ]; then
		cat $flat_customer >>$FLAT_LOADED_SO_FAR
		echo "[$DATE_NOW] removing file: $flat_customer"
		rm $flat_customer
	else
		echo "[$DATE_NOW] moving file: $flat_customer => $WORK_DIR/Failed/failed_customer_$ANSI_DATE.flat"
		cat $flat_customer >>$WORK_DIR/Failed/failed_customer_$ANSI_DATE.flat
        #### Uncomment this code if you want to see messages whenever a registration fails, but you might get one-per-minute.
        # echo "$WORK_DIR/Failed/failed_customer_$ANSI_DATE.flat file failed to load via OLR! reload it from command line: loadflatuser -aU -bU -l'ADMIN|PCGUI-DISP' -mc -n -y'EPLMNA' -d" | mailx -s"**Failed OLR registration." andrew.nisbet@epl.ca
        # exit 1
	fi
	rm $output_key 2>/dev/null
	rm $output_result 2>/dev/null
	echo "[$DATE_NOW] =="
done
exit 0
# EOF
