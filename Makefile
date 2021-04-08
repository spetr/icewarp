all:
	cd server && docker build . -t spetr/icewarp:latest

up:
	docker-compose up --detach

start:
	docker-compose start

stop:
	docker-compose stop

clean:
	rm -rf ./data/icewarp/*
	rm -rf ./data/icewarp_redis/*
	rm -rd ./data/icewarp_sql/*

fetch:
	rm -f files/IceWarpServer-*.tar.gz
	curl https://dl.icewarp.com/server/RedHat/RedHat7/icewarp13/IceWarpServer-13.0.1_RHEL7_x64.tar.gz --output ./server/IceWarpServer-13.0.1_RHEL7_x64.tar.gz