#!/bin/bash
#######################################################################
#
# Bash shell script for project olrrpt
#
# Bash shell script for reporting OLR stats and activity.
#
#    Copyright (C) 2018  Andrew Nisbet, Edmonton Public Library
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
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
# Dependancies:
#    getpathname
#    transdate
#    pipe.pl
#    mailx
#
#######################################################################

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
source /s/sirsi/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
#######################################################################
VERSION="0.7"   # Fix directory tests, change sort so non emailed duplicate accounts are listed for removal.
TMP=$(getpathname tmp)
ADDRESSES="ILSAdmins@EPL.CA"
WORK_DIR=/s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration/Rpt
RPT_SELECTION=$WORK_DIR/olr.users
RPT_NAME=olr_report.csv
RPT_FILE=$WORK_DIR/$RPT_NAME
DATE_TODAY=$(date | pipe.pl -W'\s' -oc0,c1,c2,c3 -h' ')
if [ ! -d "$WORK_DIR" ]; then
	mkdir -p $WORK_DIR
fi

###############
# Display usage message.
# param:  none
# return: none
usage()
{
	printf "Usage: %s [-option]\n" "$0" >&2
	printf " Creates a report of accounts created via OLR.\n" >&2
	printf " -a           - Search for all users created by OLR.\n" >&2
	printf " -d{YYYYMMDD[ YYYYMMDD]} - Search for all users created since ANSI date.\n" >&2
	printf "              If a second, optional date is provided, the range will be reported.\n" >&2
	printf "              Selections (S) does not include data from date 1 (d) or date 2 (d').\n" >&2
	printf "              Generally: d < S < d'\n" >&2
	printf " -D           - Report new user's since yesterday.\n" >&2
	printf " -u{YYYYMMDD} - Report all users create (OLR or in branch) and whether\n" >&2
	printf "              they use their card. If end date not included report upto yesterday.\n" >&2
	printf "              For reference, the OLR project officially started on 20180304.\n" >&2
	printf "   Version: %s\n" $VERSION >&2
	exit 1
}

# If an argument is received use it as a starting date range, but if not, search for all
# users by User ID range.
# param:  Optional start date in ANSI (YYYYMMDD) format.
# param:  Optional end date in ANSI (YYYYMMDD) format.
# return: none
search_by_date()
{
	if [ -z $1 ]; then
		# Select all the users that start with 212219, those were the known, unreserved barcodes.
		# Version II of OLR will create users with a user cat that will give more accurate counts.
		seluser -oB | egrep 212219 >$RPT_SELECTION
	elif [ ! -z $2 ]; then
		seluser -f">$1<$2" -oB | egrep 212219 >$RPT_SELECTION
	else
		seluser -f"$1" -oB | egrep 212219 >$RPT_SELECTION
	fi
	if [ -s "$RPT_SELECTION" ]; then
		# cat $RPT_SELECTION | seluser -iB -oBpfX.9007.--first_name--last_name >$RPT_FILE
		cat $RPT_SELECTION | seluser -iB -oBpfa--age--cat[2]X.9022.X.9019. | pipe.pl -m"c2:####-##-##,c3:####-##-##|True" >$WORK_DIR/tmp.0
		# If create and active date are the same, assume they haven't used their card. This is obviously incorrect
		# for cards created today, but historically, this is true.
		cat $WORK_DIR/tmp.0 | pipe.pl -bc2,c3 -i -mc4:"False_" -TCSV:"User ID,Profile,Create cate,Last activity,Uses card,Age,Ucat2,Street,Pcode" >$RPT_FILE
		# 21221900002715|EPL_ADULT|2018-06-17|2018-06-17|False|38|X|1606-9909 104 St NW|T5K XXX
		echo "=== Duplicates report" >>$RPT_FILE
		cat $WORK_DIR/tmp.0 | pipe.pl -bc2,c3 -i -mc4:"False_" | pipe.pl -dc5,c6,c7 -A -P -R | pipe.pl -Cc0:gt1 -oc1,continue -TCSV:"User ID,Profile,Create cate,Last activity,Uses card,Age,Ucat2,Street,Pcode" >>$RPT_FILE
		# 1,21221900002716,"EPL_ADULT","2018-06-17","2018-06-17","False",26,"X","507-10021 116 St. NW","T5K XXX"
		rm $WORK_DIR/tmp.0
	else
		echo "* warning, no users created by OLR." >$RPT_FILE
	fi
	cd $WORK_DIR
	echo "OLR report results dated "`date` | mailx -s"OLR report $DATE_TODAY" -a $RPT_NAME "$ADDRESSES"
}

# Asks if user would like to do what the message says.
# param:  message string.
# return: 0 if the answer was yes and 1 otherwise.
confirm()
{
	if [ -z "$1" ]; then
		printf "** error, confirm_yes requires a message.\n" >&2
		exit 1
	fi
	local message="$1"
	printf "%s? y/[n]: " "$message" >&2
	read answer
	case "$answer" in
		[yY])
			printf "yes selected.\n" >&2
			return 0
			;;
		*)
			printf "no selected.\n" >&2
			return 1
			;;
	esac
	return 1
}

# Generates a comparison of all users created since the inception of OLR, over 2
# populations; In branch and OLR, and 2 sub catagories ADULT and Juv.
# param:  customer create date selection.
# param:  report name as string.
# return: none. Produces and mails a report as a by-product.
generate_uses_card_report()
{
	if [ -z "$1" ]; then
		echo "**error input date required usually start date." >&2
		usage
	fi
	if [ -z "$2" ]; then
		echo "**error report name required." >&2
		usage
	fi
	local report="$2"
	echo "Selecting all users created since $1" >&2
	seluser -f">$1" -oBpfa 2>/dev/null >$RPT_SELECTION
	# Change all adult cards to just ADU and JUV to JUV.
	echo "distilling profiles into either JUV or ADULT." >&2
	cat $RPT_SELECTION | pipe.pl -gc1:"ADU|JUV" | pipe.pl -gc0:"^(212210|212219)" | pipe.pl -gany:ADU -i -mc1:"ADU_" | pipe.pl -gany:JUV -i -mc1:"JUV_" >$WORK_DIR/tmp.0
	# 21221026348174|ADU|20180305|20180305|
	# 21221026346426|ADU|20180305|20180305|
	# 21221026027380|ADU|20180305|20180305|
	echo "pruning dates and card types for dedupping" >&2
	# cat $WORK_DIR/tmp.0 | pipe.pl -mc2:######_,c0:######_,c3:######_ | pipe.pl -dc2,c1,c0 -A -P  > $WORK_DIR/tmp.1
	cat $WORK_DIR/tmp.0 | pipe.pl -mc2:######_,c0:######_,c3:"######_|False" > $WORK_DIR/tmp.1
	# Compare the last active to create date and if different them change c4 to 'True'
	cat $WORK_DIR/tmp.1 | pipe.pl -Bc2,c3 -i -mc4:"True_" > $WORK_DIR/tmp.2
	# 212210|ADU|201803|201804|True
	# 212219|ADU|201803|201803|False
	# Dedup the list for the counts.
	cat $WORK_DIR/tmp.2 | pipe.pl -dc0,c4 -A -P > $WORK_DIR/tmp.3
	# 8188|212210|ADU|201806|201806|False|
	# 6214|212210|ADU|201805|201806|True|
	# 1378|212219|JUV|201806|201806|False|
	# 673|212219|ADU|201805|201806|True|
	# Format for consumption
	echo "formatting results" >&2
	cat $WORK_DIR/tmp.3 | pipe.pl -oc1,c5,c0 > $WORK_DIR/tmp.4

	cat $WORK_DIR/tmp.4 | pipe.pl -gany:212210 -i -mc0:"BRA_" | pipe.pl -gany:212219 -i -mc0:"OLR_" -sc0,c1 -TCSV:"Registration tool,Uses Card,Count" >$WORK_DIR/$report
	cd $WORK_DIR
	# rm tmp.*
	echo "OLR report results dated "`date` | mailx -s"OLR in-branch vs. OLR comparison report $DATE_TODAY" -a $report "$ADDRESSES"
}

# Argument processing.
while getopts ":ad:Du:x" opt; do
  case $opt in
	a)	echo "-a all triggered" >&2
		search_by_date
		;;
	d)	echo "-a date triggered with '$OPTARG'" >&2
		REGISTRATION_DATE=$(echo "$OPTARG" | pipe.pl -oc0 -W'\s+' -tc0)
		REGISTRATION_DATE_END=$(echo "$OPTARG" | pipe.pl -oc1 -W'\s+' -tc1)
		if [ -z "$REGISTRATION_DATE_END" ]; then
			search_by_date $REGISTRATION_DATE
		else
			search_by_date $REGISTRATION_DATE $REGISTRATION_DATE_END
		fi
		;;
	D)	echo "-D date triggered." >&2
		REGISTRATION_DATE=$(transdate -d-1)
		search_by_date $REGISTRATION_DATE
		;;
	u)	echo "-u date triggered with '$OPTARG'." >&2
		RPT_FILE=in-branch_OLR.csv
		REGISTRATION_DATE=$(echo "$OPTARG" | pipe.pl -oc0 -W'\s+' -tc0)
		generate_uses_card_report $REGISTRATION_DATE $RPT_FILE
		;;
	x)	usage
		;;
	\?)	echo "Invalid option: -$OPTARG" >&2
		usage
		;;
	:)	echo "Option -$OPTARG requires an argument." >&2
		usage
		;;
  esac
done
exit 0
# EOF
