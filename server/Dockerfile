# Volumes:
#    /data
# Ports:
#    SMTP                   : 25, 587, 465
#    POP3                   : 110, 995
#    IMAP                   : 143, 993
#    IM / XMPP              : 5222, 5223, 5269
#    VoIP                   : 5060 (UDP), 5060, 5061, 10000-10256 (UDP)
#    Web                    : 80, 443
#    SOCKS                  : 1080
#    GroupWare              : 5229

FROM --platform=amd64 centos:7
LABEL maintainer="petr@icewarp.com"
LABEL description="IceWarpServer 13"
VOLUME [ "/data" ]
COPY init.sh path.dat IceWarpServer-*.tar.gz /tmp/
RUN set -ex; \
	yum update -y ;\
	yum install -y mariadb ;\
	mkdir -p /tmp/install ;\
	if [ -f /tmp/IceWarpServer-13.0.1_RHEL7_x64.tar.gz ]; then\
		tar xzf /tmp/IceWarpServer-13.0.1_RHEL7_x64.tar.gz --strip-components=1 -C /tmp/install ;\
	else\
		curl https://dl.icewarp.com/server/RedHat/RedHat7/icewarp13/IceWarpServer-13.0.1_RHEL7_x64.tar.gz --output - |\
		tar xzf - --strip-components=1 -C /tmp/install ;\
	fi ;\
	sed -i 's?>/dev/tty??' /tmp/install/platform ;\
	/tmp/install/install.sh --auto --install-dir /opt/icewarp ;\
	/opt/icewarp/tool.sh set system c_system_storage_dir_mailpath /data/mail/ ;\
	/opt/icewarp/tool.sh set system c_system_services_fulltext_database_path /data/yoda/ ;\
	/opt/icewarp/tool.sh set system c_system_storage_dir_temppath /data/temp/ ;\
	/opt/icewarp/tool.sh set system c_system_storage_dir_logpath /data/logs/ ;\
	/opt/icewarp/tool.sh set system c_system_tools_autoarchive_path /data/archive/ ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_accountsenabled 1 ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_accounts '/data/backup/accounts.db;;;;7;3' ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_asenabled 1 ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_as '/data/backup/antispam.db;;;;7;3' ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_gwenabled 1 ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_gw '/data/backup/groupware.db;;;;7;3' ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_directorycacheenabled 1 ;\
	/opt/icewarp/tool.sh set system c_system_tools_backup_db_directorycache '/data/backup/directorycache.db;;;;7;3' ;\
	/opt/icewarp/icewarpd.sh --stop ;\
	cd /opt/icewarp ;\
	tar czf calendar-default.tgz calendar ; \
	tar czf config-default.tgz config ;\
	tar czf spam-default.tgz spam ;\
	rm -rf calendar ;\
	rm -rf config ;\
	rm -rf spam ;\
	mv /tmp/path.dat /opt/icewarp/path.dat ;\
	mv /tmp/init.sh /init.sh ;\
	chmod 755 /init.sh ;\
	mkdir -p /data ;\
	yum clean all ;\
	rm -rf /tmp/* ;\
	rm -rf /var/cache/yum
EXPOSE 25/tcp 587/tcp 465/tcp 110/tcp 995/tcp 143/tcp 993/tcp 5222/tcp 5223/tcp 5269/tcp 5060/udp 5060/tcp 5061/udp 10000-10256/udp 80/tcp 443/tcp 1080/tcp 5229/tcp
ENTRYPOINT [ "/init.sh" ]
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=3s --start-period=120s CMD curl -f http://localhost/ || exit 1
