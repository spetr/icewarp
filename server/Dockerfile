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
COPY init.sh path.dat igbinary.so msgpack.so redis.so IceWarpServer-*.tar.gz /tmp/
RUN set -ex; \
	yum update -y ;\
	yum install -y epel-release ;\
	yum install -y liblzf mariadb psmisc java-1.7.0-openjdk-headless ;\
	mkdir -p /tmp/install ;\
	if [ -f /tmp/IceWarpServer-13.*_RHEL7_x64.tar.gz ]; then\
		tar xzf /tmp/IceWarpServer-13.*_RHEL7_x64.tar.gz --strip-components=1 -C /tmp/install ;\
	else\
		curl https://cdnfiles.icewarp.com/server/RedHat/RedHat7/icewarp13/IceWarpServer-13.0.2_RHEL7_x64.tar.gz --output - |\
		tar xzf - --strip-components=1 -C /tmp/install ;\
	fi ;\
	sed -i 's?>/dev/tty??' /tmp/install/platform ;\
	/tmp/install/install.sh --docker --install-dir /opt/icewarp --start-on-boot 0 ;\
	/opt/icewarp/icewarpd.sh --stop ;\
	rm -f /opt/icewarp/config/settings.cfg ;\
	cd /opt/icewarp ;\
	sed -i '/<REDIRECT>/a <ITEM><WHAT>http:\/\/*<\/WHAT><TO>https:\/\/*<\/TO><REGEX>0<\/REGEX><\/ITEM>' /opt/icewarp/config/webserver.dat ;\
	tar czf config-default.tgz config ;\
	rm -rf config ;\
	rm -rf mail ;\
	rm -rf var ;\
	mv /tmp/path.dat /opt/icewarp/path.dat ;\
	ln -s /dev/shm/var/ /opt/icewarp/var ;\
	mv /tmp/init.sh /init.sh ;\
	chmod 755 /init.sh ;\
	mv /tmp/igbinary.so /opt/icewarp/php/ext/igbinary.so ;\
	chmod 755 /opt/icewarp/php/ext/igbinary.so ;\
	mv /tmp/msgpack.so /opt/icewarp/php/ext/msgpack.so ;\
	chmod 755 /opt/icewarp/php/ext/msgpack.so ;\
	mv /tmp/redis.so /opt/icewarp/php/ext/redis.so ;\
	chmod 755 /opt/icewarp/php/ext/redis.so ;\
	sed -i '/^extension=tnef/a extension=igbinary\nextension=msgpack\nextension=redis' /opt/icewarp/php/php.ini ;\
	sed -i 's/^upload_tmp_dir.*/upload_tmp_dir = \/data\/temp\/php/g' /opt/icewarp/php/php.ini ;\
	mkdir -p /data/ ;\
	yum clean all ;\
	rm -rf /tmp/* ;\
	rm -rf /var/cache/yum ;\
	rm -f /root/icewarp-install.log ;\
	rm -f /root/icewarp-install-error.log
EXPOSE 25/tcp 587/tcp 465/tcp 110/tcp 995/tcp 143/tcp 993/tcp 5222/tcp 5223/tcp 5269/tcp 5060/udp 5060/tcp 5061/udp 10000-10256/udp 80/tcp 443/tcp 1080/tcp 5229/tcp
ENTRYPOINT [ "/init.sh" ]
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=3s --start-period=120s CMD curl -f http://localhost/ || exit 1
