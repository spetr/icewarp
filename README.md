# IceWarpServer - Docker container image

## Summary

Business email, TeamChat for project teamwork, real-time office document collaboration and online meetings. Icewarp is a commerical product with an excellent quality/price ratio. With this image, you can activate a 30-day evaluation licence for 200 mailboxes, all features included.

:warning: This docker container image is ready for evaluations, tests, demonstrations and POC purposes. :warning:

### Before the first launch

You should create folder that can be used for persistent data. For exexample:

`mkdir /data/`
`chmod a+rwx /data`

#### Run the docker stack

You can modify the command to replace hosticewarp0 with the real hostname,
'TZ=Europe/Paris' with your timezone, /data/ with the actual folder names on
your hst machine.

`docker-compose up`

##### Variables

You can provide PUBLICIP, LOCALIP and DNSSERVER as arguments to the run command, else, a script will pick up the values based on the network configuration of the container.

`-e PUBLICIP='x.x.x.x'`

`-e LOCALIP='x.x.x.x'`

`-e DNSSERVER='x.x.x.x'`

#### Initial configuration

The first command to run must be:

`docker exec -it icewarp /opt/icewarp/wizard.sh`

This command will allow you to :

- Activate the license (request evaluation or activate purchased license)
- Create first domain
- Create first administrator account

#### To get inside the container with the bash shell

`docker exec -it icewarp bash`

#### To stop the container

`docker stop -t 120 icewarp`

(Give a value of 120 or more to the parameter '-t' to allow all IceWarp processes to exit gracefully.)

#### To restart the container

`docker restart container0_icewarp`
