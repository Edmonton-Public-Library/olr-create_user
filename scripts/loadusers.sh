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
#          0.0 - Dev. 
#
##############################################################################
### Checks the Incoming directory and loads any flat files it finds.
. /s/sirsi/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')
ANSI_DATE=$(date '+%Y%m%d')
WORK_DIR=/s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration
LOG=$WORK_DIR/load.log
cd $WORK_DIR
for flat_customer in $(ls $WORK_DIR/Incoming/*.flat 2>/dev/null); do 
	retain_flat_file=0
	echo "[$DATE_NOW] loading $flat_customer" >>$LOG
	for user_id in $(cat $flat_customer | pipe.pl -gc0:USER_ID -oc1 -mc1:_#); do
		echo "[$DATE_NOW] attempt load $user_id" >>$LOG
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
	## Create
	cat $flat_customer | loadflatuser -aU -bU -l"ADMIN|PCGUI-DISP" -mc -n -y"EPLMNA" -d 2>load_user.err >load_user.keys
	## Update
	# cat $flat_customer | loadflatuser -aR -bR -l"ADMIN|PCGUI-DISP" -mu -n -y"EPLMNA" -d 2>load_user.err >load_user.keys
	cat load_user.err | egrep -e"\*\*error|\*\*USER|oralib" >>$LOG
	for line in $(cat seluser.err 2>/dev/null | egrep "error number 111"); do 
		retain_flat_file=1
		echo "[$DATE_NOW] failed load: $line" >>$LOG
	done 
	status=$(cat load_user.err 2>/dev/null | egrep 1402)
	echo "[$DATE_NOW] status '$status'" >>$LOG
	if [ "$retain_flat_file" ]; then
		echo "removing file: " >&2
		rm $flat_customer
	else
		echo "moving file: " >&2
		mv $flat_customer $WORK_DIR/Failed/failed_customer_$ANSI_DATE.flat
	fi
	rm load_user.keys
	rm load_user.err
	rm seluser.err
	echo "[$DATE_NOW] ==" >>$LOG
done
exit 0
# EOF
