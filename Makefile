all:
	docker-compose build

up:
	docker-compose up

start:
	docker-compose start

stop:
	docker-compose stop

push:
	docker-compose push

fetch:
	rm -f files/IceWarpServer-*.tar.gz
	curl https://dl.icewarp.com/server/RedHat/RedHat7/icewarp13/IceWarpServer-13.0.0_RHEL7_x64.tar.gz --output ./server/IceWarpServer-13.0.0_RHEL7_x64.tar.gz