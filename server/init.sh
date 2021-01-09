#!/bin/bash
set -e

stopServices() {
   /opt/icewarp/icewarpd.sh --stop
   exitStatus=$?
   /bin/kill -TERM "${childPid}" 2>/dev/null
   exit $exitStatus
}

cd /opt/icewarp

# Put default persistent content if data dir is empty
test -d /data/archive || mkdir -p /data/archive
test -d /data/backup || mkdir -p /data/backup
test "$(ls -A /data/calendar 2>/dev/null))" || tar xzf calendar-default.tgz -C /data/
test "$(ls -A /data/config 2>/dev/null))" || tar xzf config-default.tgz -C /data/
test -d /data/mail || mkdir -p /data/mail
test "$(ls -A /data/spam 2>/dev/null)" || tar xzf spam-default.tgz -C /data/
test -d /data/_incoming || mkdir -p /data/_incoming
test -d /data/_outgoing || mkdir -p /data/_outgoing

# Detect IP addresses and DNS servers
test -z "$PUBLICIP" && PUBLICIP=`curl http://ipecho.net/plain`
test -z "$LOCALIP" && LOCALIP=$(hostname -I)
test -z "$DNSSERVER" && DNSSERVER=`grep -i '^nameserver' /etc/resolv.conf |head -n1|cut -d ' ' -f2`

./tool.sh set system c_system_services_sip_localaccesshost    $LOCALIP
./tool.sh set system c_system_services_sip_remoteaccesshost   $PUBLICIP
./tool.sh set system c_mail_smtp_general_dnsserver            $DNSSERVER
#./tool.sh set system c_system_storage_dir_mailpath            /data/mail/
#./tool.sh set system c_system_services_fulltext_database_path /data/yoda/
#./tool.sh set system c_system_storage_dir_temppath            /data/temp/
#./tool.sh set system c_system_storage_dir_logpath             /data/logs/
#./tool.sh set system c_system_tools_autoarchive_path          /data/archive/
#./tool.sh set system c_system_tools_backup_db_accounts        '/data/backup/accounts.db;;;;7;3'
#./tool.sh set system c_system_tools_backup_db_as              '/data/backup/antispam.db;;;;7;3'
#./tool.sh set system c_system_tools_backup_db_gw              '/data/backup/groupware.db;;;;7;3'
#./tool.sh set system c_system_tools_backup_db_directorycache  '/data/backup/directorycache.db;;;;7;3'

./icewarpd.sh --start

trap stopServices TERM
/bin/sleep infinity &
childPid=$!
wait ${childPid}
trap - TERM
wait ${childPid}
