FROM --platform=amd64 centos:7
COPY init.sh IceWarpServer-*.tar.gz /tmp/
RUN set -ex; \
    yum update -y ;\
    mkdir -p /tmp/install ;\
	if [ -f /tmp/IceWarpServer-13.0.1_RHEL7_x64.tar.gz ]; then\
		tar xzf /tmp/IceWarpServer-13.0.1_RHEL7_x64.tar.gz --strip-components=1 -C /tmp/install ;\
	else\
		curl https://dl.icewarp.com/server/RedHat/RedHat7/icewarp13/IceWarpServer-13.0.1_RHEL7_x64.tar.gz --output - |\
		tar xzf - --strip-components=1 -C /tmp/install ;\
	fi ;\
    x
ENTRYPOINT ["/opt/yoda/yoda"]
