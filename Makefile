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
.PHONY: production test
test:
	scp ${LOCAL_DIR}/symphony/*.sh ${TEST_SERVER}:${REMOTE_DIR}/
	scp ${LOCAL_DIR}/watcher.js ${TEST_SERVER}:${REMOTE_DIR}/

production:
	scp ${LOCAL_DIR}/symphony/*.sh ${PRODUCTION_SERVER}:${REMOTE_DIR}/
	scp ${LOCAL_DIR}/watcher.js ${PRODUCTION_SERVER}:${REMOTE_DIR}/
