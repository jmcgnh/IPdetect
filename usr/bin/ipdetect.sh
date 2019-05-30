#!/bin/sh

### IPdetect script, version 0.5b (beta)
### (c) Mariusz Kaczmarczyk, 2005
### e-mail: koshmar@poczta.fm
### Content of this file is a subject to GPL version 2 license
### (http://www.gnu.org/licenses/gpl.html).
### There's no warranty of any kind for the software, you use it 
### for your own risk!
### See README for help

# Displays all commands executed
# Uncomment for maximum debug
# set -x;

# defaults
# do not alter these values, use configuration file instead
CHECK_IP_INTERVAL=55;
UPDATE_IP_INTERVAL=290;
STORE_FAILED_UPDATE=1;
IP_RETRIEVE_METHOD='wget';
IP_COMPARE_METHOD='last';
CHECK_DOMAIN='';
IP_RETRIEVE_TIMEOUT=20;
IP_REGEXP='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';
IP_CHANGE_EXEC='/etc/IPdetect/change_run.sh';
IP_SOURCES_FILE='/etc/IPdetect/ip_sources';
CONFIG_FILE='/etc/IPdetect/IPdetect.conf';
LOG_DATE_FORMAT='%F,%T';
LOG_FILE='/var/log/IPdetect/IPdetect.log';
LOG_EVENTS='change error';
TMP_DIR="`dirname \`mktemp -u\``";
STORE_DIR='/var/lib/IPdetect';
IP_HTML_TMP_FILE='ipdetect-ip.tmp';
STORE_FILE='last_detect';
COMMENT_REGEX='^[:space:]*[#;]{1}.*';
HOST_EXEC='/usr/bin/host';
DEV_NULL='/dev/null';
HOST_DNS_SERVER='';
DEBUG_FLAG=0;

# messages
MSG_1='ERR: Invalid IP_RETRIEVE_METHOD, should be one of: curl, wget';
MSG_2='failed';
MSG_3='ERR: Cannot retrieve valid IP';
MSG_4='NOTICE: Not checking IP - you need to wait';
MSG_5='more seconds';
MSG_6='ERR: Cannot resolve domain';
MSG_7='ERR: Cannot execute script';
MSG_8='ERR: Cannot load config file';
MSG_9='ERR: Cannot create store file';
MSG_10="ERR: CHECK_DOMAIN must be set when IP_COMPARE_METHOD = 'host'";
MSG_11='ERR: Temporary file not writable';
MSG_12='NOTICE: Not updating IP - you need to wait';

# error codes
ERR_OK=0;
ERR_NOCONFFILE=1;
ERR_BADSTOREPATH=2;
ERR_BADRETRMETHOD=3;
ERR_NOVALIDIP=4;
ERR_BADCOMPMETHOD=5;
ERR_HOSTRESOLVERR=6;
ERR_EXECFAIL=7;
ERR_BADDOMAINNAME=8;
ERR_BADTMPPERM=9;

# include config file
if [ ! -f "${CONFIG_FILE}" -o ! -r "${CONFIG_FILE}" ]; then
	echo "${MSG_8}: ${CONFIG_FILE}";
	exit ${ERR_NOCONFFILE};
fi;
. "${CONFIG_FILE}";

# startup values
FORCE_UPDATE_FLAG=0;
EXEC_FLAG=0;

# check command line parameters
if [ "$1" == "-h" -o "$1" == "--help" ]; then
	echo 'IPdetect, ver. 0.5b (beta), (c) Mariusz Kaczmarczyk <koshmar@poczta.fm>. Free software.';
	echo 'IP detection script for updating dynamic DNS services';
	echo '';
	echo "Usage: `basename $0` [-h|--help] [-f|--force-update]";
	echo "There's no warranty of any kind for this software, you use it for your own risk!";
	echo 'See README for help.';
	echo '';
	exit ${ERR_OK};
fi;
if [ "$1" == "-f" -o "$1" == "--force-update" ]; then
	FORCE_UPDATE_FLAG=1;
fi;

# prepare some essential variable values
IP_HTML_TMP_PATH="${TMP_DIR}/${IP_HTML_TMP_FILE}";
STORE_PATH="${STORE_DIR}/${STORE_FILE}";
S70_NOW="`date +%s`";

# define functions
debug_msg() {
	if [ "${DEBUG_FLAG}" -gt 0 ]; then
		echo "DEBUG: $1";
	fi;
};
log_output() {
	LOG_EVENT_ID="$1";
	touch "${LOG_FILE}";
	LOG_FLAG="`echo " ${LOG_EVENTS} " | grep -o -E " ${LOG_EVENT_ID} "`";
	if [ -z "${LOG_FLAG}" ]; then
		return;
	fi;
	ITEM_1="-${LOG_EVENT_ID}-";
	ITEM_2="`date "+${LOG_DATE_FORMAT}"`";
	ITEM_3="${IP_COMPARE_METHOD}";
	ITEM_4="${LAST_IP}";
	ITEM_5="${IP_NOW}";
	ITEM_6="${IP_SOURCE_NOW}";
	ITEM_8="$2";
	case "${LOG_EVENT_ID}" in
		'change')
			ITEM_7="${IP_SCRIPT_STATUS}";
		;;
		'nochange')
		;;
		'error')
		;;
		*)
			return;
		;;
	esac;
	TMP_LOG_ITEM="${ITEM_1} ${ITEM_2} ${ITEM_3} ${ITEM_4} ${ITEM_5} ${ITEM_6} ${ITEM_7} ${ITEM_8}";
	echo ${TMP_LOG_ITEM} >>"${LOG_FILE}";
	return;
};
ip_from_host() {
	HOST_IP='';
	if [ -z "$1" ]; then
		return;
	fi;
	HOST_IP="`${HOST_EXEC} -t A $1 ${HOST_DNS_SERVER} | \
		grep -i -E "$1 has address ${IP_REGEXP}" | \
		grep -o -E "${IP_REGEXP}"`";
};

# create store file (for last IP, detection and refresh time)
touch "${STORE_PATH}";
if [ -f "${STORE_PATH}" ]; then
	. "${STORE_PATH}";
else
	echo "${MSG_9}: ${STORE_PATH}";
	exit ${ERR_BADSTOREPATH};
fi;

# check last detection time
if [ -n "${LAST_DETECTION}" ]; then
	LAST_DET_FROM_NOW=`expr ${S70_NOW} - ${LAST_DETECTION}`;
	if [ "${LAST_DET_FROM_NOW}" -lt "${CHECK_IP_INTERVAL}" -a "${FORCE_UPDATE_FLAG}" -le 0 ]; then
		WAIT_FROM_NOW=`expr ${CHECK_IP_INTERVAL} - ${LAST_DET_FROM_NOW}`;
		echo "${MSG_4} ${WAIT_FROM_NOW} ${MSG_5}";
		exit ${ERR_OK};
	fi;
fi;

# check current public IP
for TMP_IP_SRC in `cat "${IP_SOURCES_FILE}" | grep -v -E "${COMMENT_REGEX}" | tr ' ' '_'`; do
	if [ -z "${TMP_IPADDR}" ]; then
		case "${IP_RETRIEVE_METHOD}" in
			'wget')
				touch "${IP_HTML_TMP_PATH}";
				if [ ! -f "${IP_HTML_TMP_PATH}" ]; then
					echo "${MSG_11}: ${IP_HTML_TMP_PATH}";
					exit ${ERR_BADTMPPERM};
				fi;
				wget --quiet --timeout=${IP_RETRIEVE_TIMEOUT} --output-document="${IP_HTML_TMP_PATH}" "${TMP_IP_SRC}";
				if [ -f "${IP_HTML_TMP_PATH}" ]; then
					TMP_IPADDR="`cat "${IP_HTML_TMP_PATH}" | grep -E -o "${IP_REGEXP}" | uniq`";
				fi;
				rm --force "${IP_HTML_TMP_PATH}";
			;;
			'curl')
				TMP_IPADDR="`curl --silent --connect-timeout ${IP_RETRIEVE_TIMEOUT} --url "${TMP_IP_SRC}" | grep -E -o "${IP_REGEXP}" | uniq`";
			;;
			*)
				echo "${MSG_1}";
				exit ${ERR_BADRETRMETHOD};
			;;
		esac;
		if [ -n "${TMP_IPADDR}" ]; then
			debug_msg "IP ${TMP_IP_SRC} -> ${TMP_IPADDR}";
			IP_SOURCE_NOW="${TMP_IP_SRC}";
		else
			debug_msg "IP ${TMP_IP_SRC} -> ${MSG_2}";
		fi;
	fi;
done;

# exit when no valid IP address found
if [ -z "${TMP_IPADDR}" ]; then
	log_output 'error' ${ERR_NOVALIDIP};
	echo "${MSG_3}";
	exit ${ERR_NOVALIDIP};
fi;
IP_NOW="${TMP_IPADDR}";
LAST_DETECTION="${S70_NOW}";

# check compare method
# compare last/host and current IP
case "${IP_COMPARE_METHOD}" in
	'last')
		if [ "${LAST_IP}" != "${IP_NOW}" ]; then
			EXEC_FLAG=1;
		fi;
	;;
	'host')
		if [ -z "${CHECK_DOMAIN}" ]; then
			echo "${MSG_10}";
			exit ${ERR_BADDOMAINNAME};
		fi;
		ip_from_host "${CHECK_DOMAIN}";
		if [ -z "${HOST_IP}" ]; then
			log_output 'error' ${ERR_HOSTRESOLVERR};
			echo "${MSG_6}: ${CHECK_DOMAIN}";
			exit ${ERR_HOSTRESOLVERR};
		fi;
		debug_msg "HOST ${CHECK_DOMAIN} -> ${HOST_IP}";
		if [ "${HOST_IP}" != "${IP_NOW}" ]; then
			EXEC_FLAG=1;
		fi;
	;;
	*)
		echo "${MSG_1}";
		exit ${ERR_BADCOMPMETHOD};
	;;
esac;

# execute update script
if [ "${FORCE_UPDATE_FLAG}" -gt 0 ]; then
	EXEC_FLAG=1;
fi;
if [ "${EXEC_FLAG}" -gt 0 ]; then
	if [ ! -x "${IP_CHANGE_EXEC}" ]; then
		echo "${MSG_7}";
		exit ${ERR_EXECFAIL};
	fi;
	if [ -n "${LAST_UPDATE}" ]; then
		LAST_UPD_FROM_NOW=`expr ${S70_NOW} - ${LAST_UPDATE}`;
		if [ "${LAST_UPD_FROM_NOW}" -lt "${UPDATE_IP_INTERVAL}" -a "${FORCE_UPDATE_FLAG}" -le 0 ]; then
			WAIT_FROM_NOW=`expr ${UPDATE_IP_INTERVAL} - ${LAST_UPD_FROM_NOW}`;
			echo "${MSG_12} ${WAIT_FROM_NOW} ${MSG_5}";
			exit ${ERR_OK};
		fi;
	fi;
	debug_msg "EXEC '${IP_CHANGE_EXEC} "${IP_NOW}" "${CHECK_DOMAIN}"'";
	if [ "${DEBUG_FLAG}" -gt 0 ]; then
		${IP_CHANGE_EXEC} "${IP_NOW}" "${CHECK_DOMAIN}";
	else
		${IP_CHANGE_EXEC} "${IP_NOW}" "${CHECK_DOMAIN}" 2>&1 >"${DEV_NULL}";
	fi;
	IP_SCRIPT_STATUS=${PIPESTATUS[0]};
	log_output 'change' ${FORCE_UPDATE_FLAG};
	if [ ${IP_SCRIPT_STATUS} != 0 -a "${STORE_FAILED_UPDATE}" -le 0 ]; then
		# do nothing for now
		echo '' >"${DEV_NULL}";
	else
		LAST_UPDATE="${S70_NOW}";
	fi;
else
	log_output 'nochange';
	debug_msg "EXEC none";
fi;

# save values to store file
LAST_IP="${IP_NOW}";
echo "LAST_IP='${LAST_IP}'" >"${STORE_PATH}";
echo "LAST_DETECTION=${LAST_DETECTION}" >>"${STORE_PATH}";
echo "LAST_UPDATE=${LAST_UPDATE}"  >>"${STORE_PATH}";

# goodbye, no errors
exit ${ERR_OK};
