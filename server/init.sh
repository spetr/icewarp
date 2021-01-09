#!/bin/bash

echo "Starting IceWarpServer container..."

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

# Wait for SQL server and create databases
cat <<EOT >> /root/.my.cnf
[client]
host = ${SQL_HOST}
user = ${SQL_USER}
password = ${SQL_PASSWORD}
EOT
echo "Waiting for SQL server..."
for i in {1..30}; do
   mysql -e ';' 2>/dev/null && break
   sleep 2
done
sleep 2
echo "Creating SQL databases..."
echo 'CREATE DATABASE IF NOT EXISTS iw_accounts DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' | mysql
echo 'CREATE DATABASE IF NOT EXISTS iw_antispam DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' | mysql
echo 'CREATE DATABASE IF NOT EXISTS iw_groupware DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' | mysql
echo 'CREATE DATABASE IF NOT EXISTS iw_dircache DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' | mysql
echo 'CREATE DATABASE IF NOT EXISTS iw_activesync DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' | mysql
echo 'CREATE DATABASE IF NOT EXISTS iw_webcache DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci' | mysql

# Detect IP addresses and DNS servers
test -z "$PUBLICIP" && PUBLICIP=`curl http://ipecho.net/plain 2>/dev/null`
test -z "$LOCALIP" && LOCALIP=$(hostname -I)
test -z "$DNSSERVER" && DNSSERVER=`grep -i '^nameserver' /etc/resolv.conf |head -n1|cut -d ' ' -f2`

echo ./tool.sh set system c_system_services_sip_localaccesshost "${LOCALIP}"
./tool.sh set system c_system_services_sip_localaccesshost "${LOCALIP}"

echo ./tool.sh set system c_system_services_sip_remoteaccesshost "${PUBLICIP}"
./tool.sh set system c_system_services_sip_remoteaccesshost "${PUBLICIP}"

echo ./tool.sh set system c_mail_smtp_general_dnsserver "${DNSSERVER}"
./tool.sh set system c_mail_smtp_general_dnsserver "${DNSSERVER}"

echo ./tool.sh set system c_system_storage_accounts_odbcconnstring "iw_accounts;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh set system c_system_storage_accounts_odbcconnstring "iw_accounts;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

echo ./tool.sh set system c_activesync_dbconnection "iw_activesync;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh set system c_activesync_dbconnection "iw_activesync;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

echo ./tool.sh set system c_as_challenge_connectionstring "iw_antispam;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh set system c_as_challenge_connectionstring "iw_antispam;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

echo ./tool.sh set system c_accounts_global_accounts_directorycacheconnectionstring "iw_dircache;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh set system c_accounts_global_accounts_directorycacheconnectionstring "iw_dircache;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

echo ./tool.sh set system c_gw_connectionstring "iw_groupware;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh set system c_gw_connectionstring "iw_groupware;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

# Accounts database
echo ./tool.sh create tables 0 "iw_accounts;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh create tables 0 "iw_accounts;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

# Activesync
# TODO

# Antispam database
echo ./tool.sh create tables 3 "iw_antispam;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh create tables 3 "iw_antispam;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

# Directorycache database
echo ./tool.sh create tables 4 "iw_dircache;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh create tables 4 "iw_dircache;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

# Groupware database
echo ./tool.sh create tables 2 "iw_groupware;${SQL_USER};*****;${SQL_HOST};3;2"
./tool.sh create tables 2 "iw_groupware;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

# Webmail database
# TODO

echo "Starting services..."
./icewarpd.sh --start

./tool.sh set system c_system_storage_accounts_storagemode     2
./tool.sh set system c_system_storage_accounts_odbcmultithread 1
./tool.sh set system c_system_storage_accounts_odbcmaxthreads  20
./tool.sh set system c_system_storage_dir_mailpath             /data/mail/
./tool.sh set system c_system_services_fulltext_database_path  /data/yoda/
./tool.sh set system c_system_storage_dir_temppath             /data/temp/
./tool.sh set system c_system_storage_dir_logpath              /data/logs/
./tool.sh set system c_system_tools_autoarchive_path           /data/archive/
./tool.sh set system c_system_tools_backup_db_accounts         '/data/backup/accounts.db;;;;7;3'
./tool.sh set system c_system_tools_backup_db_as               '/data/backup/antispam.db;;;;7;3'
./tool.sh set system c_system_tools_backup_db_gw               '/data/backup/groupware.db;;;;7;3'
./tool.sh set system c_system_tools_backup_db_directorycache   '/data/backup/directorycache.db;;;;7;3'

trap stopServices TERM
/bin/sleep infinity &
childPid=$!
wait ${childPid}
trap - TERM
wait ${childPid}
