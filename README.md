Container to backup directories of the local host as well as Docker volumes

# Status
[![Build Status](https://travis-ci.org/napnap75/rpi-docker-backup.svg?branch=master)](https://travis-ci.org/napnap75/rpi-docker-backup) [![Image size](https://images.microbadger.com/badges/image/napnap75/rpi-docker-backup.svg)](https://microbadger.com/images/napnap75/rpi-docker-backup "Get your own image badge on microbadger.com") [![Github link](https://assets-cdn.github.com/favicon.ico)](https://github.com/napnap75/rpi-docker-backup) [![Docker hub link](https://www.docker.com/favicon.ico)](https://hub.docker.com/r/napnap75/rpi-docker-backup/)

# Content
This image is based [my own Alpine Linux base image](https://hub.docker.com/r/napnap75/rpi-alpine-base/).

This image contains :

- [Restic](https://restic.github.io/).

# Usage (installation)
## Common rules
1. Map the root directory of your host with the `/root_fs` folder in the container (this will allow to access the files to backup).
2. Map the Docker socket inside the container (this will allow to discover automatically the containers and list the things to backup).
3. Set the `RESTIC_PASSWORD` environment variable to the name of a file containing the password used by Restic to protect the repository. I advise to make this password available through Docker Swarm secrets.
4. Set the `RESTIC_REPOSITORY` environment variable to the description of the repository (see bellow).

## Local backup
5. Map the directory where you want to store the backups in the container.
6. Set `RESTIC_REPOSITORY` environment variable to the path (inside the container) of this directory.

## SFTP backup
5. Set the `RESTIC_REPOSITORY` environment variable to the form `sftp:USERNAME_ON_THE_REMOTE_HOST@NAME_OFF_THE_REMOTE_HOST:DIRECTORY_WHERE_TO_BACKUP_ON_THE_REMOTE_HOST`.
6. Set the `SFTP_HOST` environment variable to the name of the remote host.
7. Set the `SFTP_KEY` environment variable to the name of a file containing the SSH key that will be used to connect to the remote host.
8. If it's not 22, Set the `SFTP_PORT` environment variable to the SSH port number on the remote host.

# Usage (telling what to backup)
On your other containers (because the Docker socket is mounted on the backup container, it will be able to read it directly), add the following labels to tell what to backup :
- `napnap75.backup.dirs=DIRECTORY_ON_THE_HOST, ANOTHER_DIRECTORY` to backup directories from the Docker host
- `napnap75.backup.volumes=VOLUME_NAME, ANOTHER_VOLUME` to backup Docker volumes

# Usage example
TBD
