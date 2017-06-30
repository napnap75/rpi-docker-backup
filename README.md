# Status
[![Build Status](https://travis-ci.org/napnap75/rpi-docker-backup.svg?branch=master)](https://travis-ci.org/napnap75/rpi-docker-backup) [![Image size](https://images.microbadger.com/badges/image/napnap75/rpi-docker-backup.svg)](https://microbadger.com/images/napnap75/rpi-docker-backup "Get your own image badge on microbadger.com") [![Github link](https://assets-cdn.github.com/favicon.ico)](https://github.com/napnap75/rpi-docker-backup) [![Docker hub link](https://www.docker.com/favicon.ico)](https://hub.docker.com/r/napnap75/rpi-docker-backup/)

# Content
This image is based [my own Alpine Linux base image](https://hub.docker.com/r/napnap75/rpi-alpine-base/).

This image contains :
- [Restic](https://restic.github.io/).

This image runs a backup every night (between midnight and 7 AM) on all the containers running on the host. For each container, the script will backup the followin parts (depending of the container labels) :
- The volumes specified by the label `napnap75.backup.volumes`
- The directories specified by the label `napnap75.backup.dirs`

# Usage (installation)
## Common rules
1. Map the root directory of your host with the `/root_fs` folder in the container (this will allow the script to access the files to backup).
2. Map the Docker socket inside the container (this will allow the script to discover automatically the containers and list the things to backup).
3. Set the `RESTIC_PASSWORD` environment variable to the name of a file containing the password used by Restic to protect the repository. I advise to make this password available through Docker Swarm secrets.
4. Set the `RESTIC_REPOSITORY` environment variable to the description of the repository (see below).

## Local backup
5. Map the directory where you want to store your backups in the container.
6. Set `RESTIC_REPOSITORY` environment variable to the path (inside the container) of this directory.

## SFTP backup
5. Set the `RESTIC_REPOSITORY` environment variable to the form `sftp:USERNAME_ON_THE_REMOTE_HOST@%NAME_OFF_THE_REMOTE_HOST%:%DIRECTORY_WHERE_TO_BACKUP_ON_THE_REMOTE_HOST%`.
6. Set the `SFTP_HOST` environment variable to the name of the remote host.
7. Set the `SFTP_KEY` environment variable to the name of a file containing the SSH key that will be used to connect to the remote host. I advise to make this key available through Docker Swarm secrets.
8. If it's not 22, set the `SFTP_PORT` environment variable to the SSH port number on the remote host.

# Usage (telling what to backup)
On your other containers (because the Docker socket is mounted on the backup container, the script will be able to read it directly), add the following labels to tell what to backup :
- `napnap75.backup.dirs=%DIRECTORY_ON_THE_HOST%, %ANOTHER_DIRECTORY%` to backup directories from the Docker host
- `napnap75.backup.volumes=%VOLUME_NAME%, %ANOTHER_VOLUME%` to backup Docker volumes

# Usage (additional functionnalities)
- The script is able to post a message to a Slack webhook when a backup is finished or failed. Add the `SLACK_URL` environment variable with the URL of your Slack webhook.

# Examples
## Backup a directory to a local repo (docker run on a single host)
1. Run the backup script container : `docker run -v /home/backup:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v /home/backup/password:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" -v /var/run/docker.sock:/var/run/docker.sock:ro -v /:/root_fs:ro napnap75/rpi-docker-backup:latest`
2. Run a Transmission container and tell the backup script to backup its home directory : `docker run -v /home/transmission:/home -v /home/media:/media --label "napnap75.backup.dirs=/home/transmission" napnap75/rpi-transmission:latest`

## Backup a volume to a sftp repo (docker stack on a swarm)
This stack file will run one backup instance on each node of the swarm and backup the configuration volume of the portainer container.
```
version: "3.1"
services :
  portainer:
    image: portainer/portainer:linux-arm
    ports:
      - 9000:9000
    volumes:
      - portainer_data:/data
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "napnap75.backup.volumes=portainer_data"
    deploy:
      placement:
        constraints: [node.role == manager]
  docker-backup:
    image: napnap75/rpi-docker-backup:latest
    volumes:
      - /:/root_fs:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - SFTP_HOST=myhost.com
      - SFTP_PORT=22
      - SFTP_KEY=/run/secrets/private.key
      - RESTIC_PASSWORD=/run/secrets/restic.password
      - RESTIC_REPOSITORY=sftp:myuser@myhost.com:restic
    secrets:
      - private.key
      - restic.password
    deploy:
      mode: global
secrets:
  private.key:
    external: true
  restic.password:
    external: true
volumes:
  portainer_data:
```
