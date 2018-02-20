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
#          1.1 - Cut-over to production (Tue Feb 20 09:32:48 MST 2018). 
#          1.0 - Updated duplicate user database with newly created accounts. 
#          0.1 - Updated load user to use ssh in different way. 
#          0.0 - Dev. 
#
##############################################################################
### Checks the Incoming directory and loads any flat files it finds.
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')
ANSI_DATE=$(date '+%Y%m%d')
WORK_DIR=/s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration
LOCAL_DIR=/home/ilsadmin/duplicate_user/incoming
USER_FILE=$LOCAL_DIR/users.lst
PY_SCRIPT_DIR=/home/ilsadmin/duplicate_user/scripts/duplicate_user.py
PY_SCRIPT_ARGS="-b$USER_FILE"
LOG=$WORK_DIR/load.log
TEST_ILS="sirsi@edpl-t.library.ualberta.ca"  # Test server is default ILS to write to.
PROD_ILS="sirsi@eplapp.library.ualberta.ca"  # Production server is default ILS to write to.
SERVER="$PROD_ILS"                           # Current server target.
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
	ssh -t sirsi@$SERVER << EOSSH 2>load_user.err >load_user.keys
cat $flat_customer | loadflatuser -aU -bU -l"ADMIN|PCGUI-DISP" -mc -n -y"EPLMNA" -d 
exit
EOSSH
	# cat $flat_customer | loadflatuser -aU -bU -l"ADMIN|PCGUI-DISP" -mc -n -y"EPLMNA" -d 2>load_user.err >load_user.keys
	## Update
	# cat $flat_customer | loadflatuser -aR -bR -l"ADMIN|PCGUI-DISP" -mu -n -y"EPLMNA" -d 2>load_user.err >load_user.keys
	cat load_user.err | egrep -e"\*\*error|\*\*USER|oralib" >>$LOG
	for line in $(cat load_user.err 2>/dev/null | egrep "error number 111"); do 
		retain_flat_file=1
		echo "[$DATE_NOW] failed load: $line" >>$LOG
	done 
	status=$(cat load_user.err 2>/dev/null | egrep 1402)
	echo "[$DATE_NOW] status '$status'" >>$LOG
	if [ "$retain_flat_file" ]; then
		# Before we remove the successful flat file, let's use the data in it to update duplicate user database.
        # UKEY|FNAME|LNAME|EMAIL|DOB|
		# Will convert into the following.
        # 1385638|Bonita|Guler|bonitas.92@hotmail.com|1974-01-06|
		# {"index": {"_id": "1385638"}}
		# {"lname": "Guler", "dob": "1974-01-06", "email": "bonitas.92@hotmail.com", "fname": "Bonita"}
		# This code is taken from sample_users.sh in /s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration.
		# seluser  -oU--first_name--last_nameX.9007.s 2>/dev/null | pipe.pl -m'c4:####-##-##' -nc3 -I >$USER_FILE
		# Get the user ids
		for user_id in $(cat $flat_customer | pipe.pl -gc0:USER_ID -mc1:_# -oc1); do
			ssh -t sirsi@$SERVER << EOSSH  2>>load_user.err >>$USER_FILE 
echo $user_id | seluser -iB -oU--first_name--last_nameX.9007.s | pipe.pl -m'c4:####-##-##' -nc3 -I
exit
EOSSH
		done
		# The file will be full of stuff from the ssh command as well so clean that out.
		cat "$USER_FILE" | pipe.pl -gc0:"^\d+" >clean.tmp
		mv clean.tmp $USER_FILE
		# now convert the customers and load the results. This comes from fetch_new_users.sh
		if [ -s "$USER_FILE" ]; then
			/usr/bin/python $PY_SCRIPT_DIR $PY_SCRIPT_ARGS
			rm $USER_FILE # this will rm the file if it had any content.
		fi
		# Even if the above fails, all it means is the duplciate data base doesn't get updated. 
		# still remove the flat file, all new customers created since the last time fetch_new_users.sh
		# ran will be added tonight.
		echo "removing file: " >&2
		rm $flat_customer
	else
		echo "moving file: " >&2
		mv $flat_customer $WORK_DIR/Failed/failed_customer_$ANSI_DATE.flat
	fi
	rm load_user.keys
	rm load_user.err
	echo "[$DATE_NOW] ==" >>$LOG
done
exit 0
# EOF
