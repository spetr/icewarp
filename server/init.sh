#!/bin/bash

stopServices() {
   /opt/icewarp/icewarpd.sh --stop
   exitStatus=$?
   /bin/kill -TERM "${childPid}" 2>/dev/null
   exit $exitStatus
}

checkMySQLTableExists() {
   if [ $(mysql -N -s -e "select count(*) from information_schema.TABLES where TABLE_SCHEMA='$1' and TABLE_NAME='$2';") -eq 1 ]; then
      return 0
   else
      return 1
   fi
}

cd /opt/icewarp

echo 'Starting IceWarp Server'

test -z "$SQL_PASSWORD_FILE" || SQL_PASSWORD=$(<$SQL_PASSWORD_FILE)

# Detect IP addresses and DNS servers if not set with ENV
echo -n 'Testing network connectivity ... '
test -z "$PUBLICIP" && PUBLICIP=$(curl http://ipecho.net/plain 2>/dev/null)
test -z "$LOCALIP" && LOCALIP=$(hostname -I)
test -z "$DNSSERVER" && DNSSERVER=$(grep -i '^nameserver' /etc/resolv.conf |head -n1|cut -d ' ' -f2)
echo 'OK'

# Put default persistent content if data dir is empty
test -d /data/archive || (echo 'Creating archive folder'; mkdir -p /data/archive)
test -d /data/backup || (echo 'Creating backup filder'; mkdir -p /data/backup)
test -z "$(ls -A /data/calendar 2>/dev/null))" || (echo 'Initializing calendar folder'; tar xzf calendar-default.tgz -C /data/)
test -z "$(ls -A /data/config 2>/dev/null))" || (echo 'Initializing config folder'; tar xzf config-default.tgz -C /data/)
test -d /data/mail || (echo "Creating mail folder"; mkdir -p /data/mail)
test -z "$(ls -A /data/spam 2>/dev/null)" || (echo 'Initializing spam folder'; tar xzf spam-default.tgz -C /data/)
test -d /data/temp || (echo 'Creating temp folder'; mkdir -p /data/temp)
test -d /data/temp/php || (echo 'Creating php temp folder'; mkdir -p /data/temp/php)
test -d /data/_incoming || (echo 'Creating _incoming folder'; mkdir -p /data/_incoming)
test -d /data/_outgoing || (echo 'Creating _outgoing folder'; mkdir -p /data/_outgoing)

# Configure IceWarp before start
echo -n 'Configuration tasks 1/2 ... '
if [ -z "$REDIS_HOST" ]; then
   sed -i 's/^session\.save_handler.*/session\.save_handler = files/g' /opt/icewarp/php/php.ini 
   sed -i 's/^session\.save_path.*/session\.save_path = \/tmp/g' /opt/icewarp/php/php.ini 
else
   sed -i 's/^session\.save_handler.*/session\.save_handler = redis/g' /opt/icewarp/php/php.ini 
   sed -i "s/^session\.save_path.*/session\.save_path = tcp:\/\/${REDIS_HOST}:6379/g" /opt/icewarp/php/php.ini 
fi
./tool.sh set system c_system_services_sip_localaccesshost "${LOCALIP}" >/dev/null
./tool.sh set system c_system_services_sip_remoteaccesshost "${PUBLICIP}" >/dev/null
./tool.sh set system c_mail_smtp_general_dnsserver "${DNSSERVER}" >/dev/null
./tool.sh set system c_system_storage_accounts_odbcconnstring "iw_accounts;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
./tool.sh set system c_activesync_dbconnection "iw_activesync;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
./tool.sh set system c_as_challenge_connectionstring "iw_antispam;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
./tool.sh set system c_accounts_global_accounts_directorycacheconnectionstring "iw_dircache;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
./tool.sh set system c_gw_connectionstring "iw_groupware;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
echo 'OK'

# Wait for SQL server
echo -n 'Checking SQL server connection ... '
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
echo 'OK'

# Create SQL databases
echo -n 'Checking SQL databases ... '
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_accounts DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_antispam DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_groupware DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_dircache DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_activesync DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -N -s -e 'CREATE DATABASE IF NOT EXISTS iw_webcache DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
echo 'OK'

# Create tables - Accounts database
if ! checkMySQLTableExists 'iw_accounts' 'MetaData'; then
   echo -n 'Creating tables in accounts database ... '
   ./tool.sh create tables 0 "iw_accounts;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
   if [ "$?" -ne 0 ]; then
      echo 'Error, can not create tables in accounts database.'
      exit 1
   fi
   echo 'OK'
fi

# Create tables - Activesync
# TODO

# Create tables - Antispam database
if ! checkMySQLTableExists 'iw_antispam' 'MetaData'; then
   echo -n 'Creating tables in antispam database ... '
   ./tool.sh create tables 3 "iw_antispam;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
   if [ "$?" -ne 0 ]; then
      echo 'Error, can not create tables in antispam database.'
      exit 1
   fi
   echo 'OK'
fi

# Create tables - Directorycache database
if ! checkMySQLTableExists 'iw_dircache' 'MetaData'; then
   echo -n 'Creating tables in directory cache database ... '
   ./tool.sh create tables 4 "iw_dircache;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
   if [ "$?" -ne 0 ]; then
      echo 'Error, can not create tables in directory cache database.'
      exit 1
   fi
   echo 'OK'
fi

# Create tables - Webmail database
# TODO

echo 'Starting services...'
./icewarpd.sh --start

# Create tables - Create groupware database
if ! checkMySQLTableExists 'iw_groupware' 'MetaData'; then
   echo -n 'Creating tables in groupware database ... '
   ./tool.sh create tables 2 "iw_groupware;${SQL_USER};${SQL_PASSWORD};${SQL_HOST};3;2" >/dev/null
   if [ "$?" -ne 0 ]; then
      echo 'Error, can not create tables in groupware database.'
      exit 1
   fi
   ./tool.sh set system c_teamchat_active 1
   echo 'OK'
fi

echo -n 'Configuration tasks 2/2 ... '
./tool.sh set system c_system_storage_accounts_storagemode '2' >/dev/null
./tool.sh set system c_system_storage_accounts_odbcmultithread '1' >/dev/null
./tool.sh set system c_system_storage_accounts_odbcmaxthreads '20' >/dev/null
./tool.sh set system c_system_storage_dir_mailpath '/data/mail/' >/dev/null
./tool.sh set system c_system_services_fulltext_database_path '/data/yoda/' >/dev/null
./tool.sh set system c_system_storage_dir_temppath '/data/temp/' >/dev/null
./tool.sh set system c_system_storage_dir_logpath '/data/logs/' >/dev/null
./tool.sh set system c_system_tools_autoarchive_path '/data/archive/' >/dev/null
./tool.sh set system c_system_tools_backup_db_accounts '/data/backup/accounts.db;;;;7;3' >/dev/null
./tool.sh set system c_system_tools_backup_db_as '/data/backup/antispam.db;;;;7;3' >/dev/null
./tool.sh set system c_system_tools_backup_db_gw '/data/backup/groupware.db;;;;7;3' >/dev/null
./tool.sh set system c_system_tools_backup_db_directorycache '/data/backup/directorycache.db;;;;7;3' >/dev/null
echo 'OK'

echo 'Server started'

if [ ! -f /data/license.key ]; then
   echo ''
   echo '****************************************************************************'
   echo '* No license key found.                                                    *'
   echo '* Please run wizard.sh or wizard.cmd to activate license or request trial! *'
   echo '****************************************************************************'
fi

trap stopServices TERM
/bin/sleep infinity &
childPid=$!
wait ${childPid}
trap - TERM
wait ${childPid}
