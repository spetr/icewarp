#!/bin/bash

echo 'Starting IceWarpServer container...'

set -e

stopServices() {
   /opt/icewarp/icewarpd.sh --stop
   exitStatus=$?
   /bin/kill -TERM "${childPid}" 2>/dev/null
   exit $exitStatus
}

checkMySQLTableExists() {
   if [ $(mysql -N -s -e "select count(*) from information_schema.TABLES where TABLE_SCHEMA='$1' and TABLE_NAME='$2';") -eq 1 ]; then
      echo "Table $1 / $2 exists! ...";
      return 0
   else
      echo "Table $1 / $2 does not exist! ..."
      return 1
   fi
}

cd /opt/icewarp

# Detect IP addresses and DNS servers if not set with ENV
echo 'Testing network'
test -z "$PUBLICIP" && PUBLICIP=$(curl http://ipecho.net/plain 2>/dev/null)
test -z "$LOCALIP" && LOCALIP=$(hostname -I)
test -z "$DNSSERVER" && DNSSERVER=$(grep -i '^nameserver' /etc/resolv.conf |head -n1|cut -d ' ' -f2)

# Put default persistent content if data dir is empty
echo 'Persistent storage check'
test -d /data/archive || (echo 'Creating archive folder'; mkdir -p /data/archive)
test -d /data/backup || (echo 'Creating backup filder'; mkdir -p /data/backup)
test -z "$(ls -A /data/calendar 2>/dev/null))" || (echo 'Initializing calendar folder'; tar xzf calendar-default.tgz -C /data/)
test -z "$(ls -A /data/config 2>/dev/null))" || (echo 'Initializing config folder'; tar xzf config-default.tgz -C /data/)
test -d /data/mail || (echo "Creating mail folder"; mkdir -p /data/mail)
test -z "$(ls -A /data/spam 2>/dev/null)" || (echo 'Initializing spam folder'; tar xzf spam-default.tgz -C /data/)
test -d /data/_incoming || (echo 'Creating _incoming folder'; mkdir -p /data/_incoming)
test -d /data/_outgoing || (echo 'Creating _outgoing folder'; mkdir -p /data/_outgoing)

# Configure IceWarp before start
echo 'IceWarp configuration before start'
./tool.sh set system c_system_services_sip_localaccesshost "${LOCALIP}"
./tool.sh set system c_system_services_sip_remoteaccesshost "${PUBLICIP}"
./tool.sh set system c_mail_smtp_general_dnsserver "${DNSSERVER}"
./tool.sh set system c_system_storage_accounts_odbcconnstring "iw_accounts;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
./tool.sh set system c_activesync_dbconnection "iw_activesync;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
./tool.sh set system c_as_challenge_connectionstring "iw_antispam;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
./tool.sh set system c_accounts_global_accounts_directorycacheconnectionstring "iw_dircache;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
./tool.sh set system c_gw_connectionstring "iw_groupware;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"

# Wait for SQL server and create databases
echo 'Checking SQL server connection'
cat <<EOT >/root/.my.cnf
[client]
host = ${SQL_HOST}
user = ${SQL_USER}
password = ${SQL_PASSWORD}
EOT
SQL_OK=false
for i in {1..30}; do
   mysql -e ';' 2>/dev/null && SQL_OK=true
   test "$SQL_OK" = 'true' && break
   sleep 2
done
test "$SQL_OK" != 'true' && (echo 'SQL connection error'; exit 1)
sleep 1
echo 'Checking and creating SQL databases...'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_accounts DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_antispam DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_groupware DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_dircache DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_activesync DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_webcache DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'

# Accounts database
if checkMySQLTableExists 'iw_accounts' 'MetaData'; then
   echo ./tool.sh create tables 0 "iw_accounts;${SQL_USER};*****;${SQL_HOST};3;2"
   ./tool.sh create tables 0 "iw_accounts;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
fi

# Activesync
# TODO

# Antispam database
if checkMySQLTableExists 'iw_antispam' 'MetaData'; then
   echo ./tool.sh create tables 3 "iw_antispam;${SQL_USER};*****;${SQL_HOST};3;2"
   ./tool.sh create tables 3 "iw_antispam;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
fi

# Directorycache database
if checkMySQLTableExists 'iw_dircache' 'MetaData'; then
   echo ./tool.sh create tables 4 "iw_dircache;${SQL_USER};*****;${SQL_HOST};3;2"
   ./tool.sh create tables 4 "iw_dircache;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
fi

# Webmail database
# TODO

echo 'Starting services...'
./icewarpd.sh --start

# Create groupware database
if checkMySQLTableExists 'iw_groupware' 'MetaData'; then
   echo ./tool.sh create tables 2 "iw_groupware;${SQL_USER};*****;${SQL_HOST};3;2"
   ./tool.sh create tables 2 "iw_groupware;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2"
fi

./tool.sh set system c_system_storage_accounts_storagemode '2'
./tool.sh set system c_system_storage_accounts_odbcmultithread '1'
./tool.sh set system c_system_storage_accounts_odbcmaxthreads '20'
./tool.sh set system c_system_storage_dir_mailpath '/data/mail/'
./tool.sh set system c_system_services_fulltext_database_path '/data/yoda/'
./tool.sh set system c_system_storage_dir_temppath '/data/temp/'
./tool.sh set system c_system_storage_dir_logpath '/data/logs/'
./tool.sh set system c_system_tools_autoarchive_path '/data/archive/'
./tool.sh set system c_system_tools_backup_db_accounts '/data/backup/accounts.db;;;;7;3'
./tool.sh set system c_system_tools_backup_db_as '/data/backup/antispam.db;;;;7;3'
./tool.sh set system c_system_tools_backup_db_gw '/data/backup/groupware.db;;;;7;3'
./tool.sh set system c_system_tools_backup_db_directorycache '/data/backup/directorycache.db;;;;7;3'

trap stopServices TERM
/bin/sleep infinity &
childPid=$!
wait ${childPid}
trap - TERM
wait ${childPid}
