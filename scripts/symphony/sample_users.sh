#!/bin/bash
####################################################################
#
# Collect a sample of users and accompanying information.
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
# Copyright (c) Friday, February  3, 2017  5:17:54 PM MST
# Rev: 0.1
#
####################################################################
# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
###############################################
# *** Edit these to suit your environment *** #
source /software/EDPL/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################
SU_HOME=/software/EDPL/Unicorn/EPLwork/cronjobscripts/OnlineRegistration
# This script features the ability to collect new users since the last time it ran.
# We save a file with today's date, and then use that with -f on seluser.
DATE_FILE=$SU_HOME/last.run
# Is it better to discribe the groups that you don't want. If we take the list of
# user profiles we want - to start off with - then not them against all profiles,
# We end up with an ever increasing list of profiles we don't want, but by negating
# that selection we end up with new desireable profiles as well.
DESIREABLE_PROFILES="EPL_NOVIDG,EPL_JNOVG,EPL_ADULT,EPL_JUV,EPL_ADU01,EPL_ADU05,EPL_ADU10,EPL_ADU1FR,EPL_ACCESS,EPL_CONCOR,EPL_CORP,EPL_GMU,EPL_HOME,EPL_JONLIN,EPL_JUV01,EPL_JUV10,EPL_JUV05,EPL_JUVIND,EPL_JUV,EPL_JUVGR,EPL_NORQ,EPL_ONLIN,EPL_THREE,EPL_TRESID,EPL_UAL,EPL_VISITR"
echo "$DESIREABLE_PROFILES" | pipe.pl -W',' -K >$SU_HOME/good.profiles
getpol -tUPRF | pipe.pl -oc2 >$SU_HOME/all.profiles
UNDESIREABLE_PROFILES=$(echo "$SU_HOME/all.profiles not $SU_HOME/good.profiles" | diff.pl -ec0 -fc0 | pipe.pl -h',' -H -P -j)
printf "%s\n" $UNDESIREABLE_PROFILES >&2
if [[ -s "$DATE_FILE" ]]; then
	# UKEY|FNAME|LNAME|EMAIL|DOB|
	last_run_date=$(cat $DATE_FILE)
	# This will keep adding to the file in the case that the script that picks it up at the other
	# end has failed to pick it up. The caller script should then zero out this file when done.
	seluser -f"$last_run_date" -p"~$UNDESIREABLE_PROFILES" -oU--first_name--last_nameX.9007.s 2>/dev/null | pipe.pl -m'c4:####-##-##' -nc3 -I >>$SU_HOME/users.lst
else # Never been run.
	seluser -p"~$UNDESIREABLE_PROFILES" -oU--first_name--last_nameX.9007.s 2>/dev/null | pipe.pl -m'c4:####-##-##' -nc3 -I >$SU_HOME/users.lst
	# UKEY|FNAME|LNAME|EMAIL|DOB|
	# 1466890|Memet|Guler|zoralguleryahoocom|1974-01-06|
	# 1466891|Bernard|Rivera|faustinerivera123gmailcom|2002-10-06|
	# 1466892|Hani|Abdikadir Odawa|haniabdikadir123gmailcom|1999-01-01|
fi
# That is for all users, but on update we just want the user since the last time we did this. In that case
# we will save the date last run as a zero-byte file.
DATE_TODAY=$(transdate -d-0)
echo "$DATE_TODAY" > $DATE_FILE
# EOF
