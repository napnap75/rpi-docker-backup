# Status
[![Build Status](https://travis-ci.org/napnap75/rpi-docker-backup.svg?branch=master)](https://travis-ci.org/napnap75/rpi-docker-backup) [![Image size](https://images.microbadger.com/badges/image/napnap75/rpi-docker-backup.svg)](https://microbadger.com/images/napnap75/rpi-docker-backup "Get your own image badge on microbadger.com") [![Github link](https://assets-cdn.github.com/favicon.ico)](https://github.com/napnap75/rpi-docker-backup) [![Docker hub link](https://www.docker.com/favicon.ico)](https://hub.docker.com/r/napnap75/rpi-docker-backup/)

# Content
This image is based [my own Alpine Linux base image](https://hub.docker.com/r/napnap75/rpi-alpine-base/).

This image contains :
- [Restic](https://restic.github.io/).

This image runs a backup every night (between midnight and 7 AM) of the followin parts of all the containers running on the host :
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

# Examples
## Backup a directory to a local repo (docker run)
1. Run the backup script container : `docker run -v /home/backup:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v /home/backup/password:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" -v /var/run/docker.sock:/var/run/docker.sock:ro -v /:/root_fs:ro napnap75/rpi-docker-backup:latest`
2. Run a Transmission container and tell the backup script to backup its home directory : `docker run -v /home/transmission:/home -v /home/media:/media --label "napnap75.backup.dirs=/home" napnap75/rpi-transmission:latest`

