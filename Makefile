###############################################################################
# 
# Manages the distribution of the loadusers.sh script which is a dependancy for
# OnlineRegistration.
#
# Wed Dec 20 09:41:24 MST 2017
# 
###############################################################################

TEST_SERVER=sirsi@edpl-t.library.ualberta.ca
PRODUCTION_SERVER=sirsi@eplapp.library.ualberta.ca
REMOTE_DIR=/s/sirsi/Unicorn/EPLwork/cronjobscripts/OnlineRegistration
LOCAL_DIR=scripts
APP=loadusers.sh
.PHONY: production test
test: ${LOCAL_DIR}/${APP}
	scp ${LOCAL_DIR}/${APP} ${TEST_SERVER}:${REMOTE_DIR}/${APP}
	
production: ${LOCAL_DIR}/${APP}
	scp ${LOCAL_DIR}/${APP} ${TEST_SERVER}:${REMOTE_DIR}/${APP}
	scp ${LOCAL_DIR}/${APP} ${PRODUCTION_SERVER}:${REMOTE_DIR}/${APP}
