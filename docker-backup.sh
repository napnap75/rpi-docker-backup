#!/bin/bash

# Sleep until the given time of the day (or next day)
sleep_until() {
    local slp tzoff now
    local hms=(${1//:/ })
    printf -v now '%(%s)T' -1
    printf -v tzoff '%(%z)T\n' $now
    tzoff=$((0${tzoff:0:1}(3600*${tzoff:1:2}+60*${tzoff:3:2})))
    slp=$(((86400+(now-now%86400)+10#$hms*3600+10#${hms[1]}*60+${hms[2]}-tzoff-now)%86400))
    printf 'sleep %ss, -> %(%c)T\n' $slp $((now+slp))
    sleep $slp
}

# Check the connection to the host and ensure the repository is created
function check_connection {
	# First check if the repository exist and create it otherwise
	# NB : this will ignore any other error
	restic -p "$RESTIC_PASSWORD" check &> restic_check.log
	if grep -q "Is there a repository at the following location" restic_check.log ; then
		echo "[INFO] Repository not found, creating it"
		restic -p "$RESTIC_PASSWORD" init
		if [ $? -ne 0 ]; then
			echo "[ERROR] Unable to create repository"
			return 1
		fi
	fi
	rm restic_check.log

	# Then check the connection to the repository
	restic -p "$RESTIC_PASSWORD" check
	return $?
}

# Backup one directory using Restic
function backup_dir {
	# Check if the dir to backup is mounted as a subdirectory of /root inside this container
	if [ -d "/root_fs$1" ] ; then
		restic -p "$RESTIC_PASSWORD" backup /root_fs$1
	else
		echo "[ERROR] Directory" $1 "not found. Have you mounted the root fs from your host with the following option : '-v /:/root_fs:ro' ?"
	fi
}

# Find all the directories to backup and call backup_dir for each one
function run_backup {
	# List all the containers
	containers=$(curl -s --unix-socket /var/run/docker.sock http:/v1.26/containers/json)
	for container_id in $(echo $containers | jq ".[].Id") ; do
		container=$(echo $containers | jq -c ".[] | select(.Id==$container_id)")

		# Get the name and namespace (in case of a container run in a swarm stack)
		container_name=$(echo $container | jq -r ".Names | .[0]" | cut -d'.' -f1 | cut -d'/' -f2)
		namespace=$(echo $container | jq -r ".Labels | .[\"com.docker.stack.namespace\"]")

		# Backup the dirs labelled with "napnap75.backup.dirs"
		if $(echo $container | jq ".Labels | has(\"napnap75.backup.dirs\")") ; then
			for dir_name in $(echo $container | jq -r ".Labels | .[\"napnap75.backup.dirs\"]") ; do
				echo "[INFO] Backing up dir" $dir_name "for container" $container_name
				backup_dir $dir_name
			done
		fi

		# Backup the volumes labelled with "napnap75.backup.volumes"
		if $(echo $container | jq ".Labels | has(\"napnap75.backup.volumes\")") ; then
			for volume_name in $(echo $container | jq -r ".Labels | .[\"napnap75.backup.volumes\"]") ; do
				if [ $namespace != "null" ] ; then volume_name="${namespace}_${volume_name}" ; fi
				volume_mount=$(echo $container | jq -r ".Mounts[] | select(.Name==\"$volume_name\") | .Source")
				echo "[INFO] Backing up volume" $volume_name "with mount" $volume_mount "for container" $container_name
				backup_dir $volume_mount
			done
		fi
	done
}

# Set the hostname to the node name when used with Docker Swarm
NODE_NAME=$(curl -s --unix-socket /var/run/docker.sock http:/v1.26/info | jq -r ".Name")
if [[ "$NODE_NAME" != "" ]] ; then HOSTNAME="$NODE_NAME" ; fi

# When used with SFTP
if [[ "$RESTIC_REPOSITORY" = sftp:* ]] ; then
	cp $SFTP_KEY /tmp/foreign_host_key
	chmod 400 /tmp/foreign_host_key
	SFTP_KEY=/tmp/foreign_host_key

	if [ ! -d "/root/.ssh" ] ; then mkdir /root/.ssh ; fi
	echo "Host $SFTP_HOST" > /root/.ssh/config
	if [[ "$SFTP_PORT" != "" ]] ; then echo "Port $SFTP_PORT" >> /root/.ssh/config ; fi
	echo "IdentityFile $SFTP_KEY" >> /root/.ssh/config

	echo "[DEBUG] Updated /root/.ssh/config"
	cat /root/.ssh/config
	
	echo "ls" | sftp -oStrictHostKeyChecking=no -v -b - app-admin@sftp-test-server
fi

# First check the connection and the repository
echo "[INFO] Trying to connect to repository"
check_connection
if [ $? == 0 ] ; then
	if [ "$1" == "run-once" ] ; then
		# Run only once, mainly for tests purpose
		start_time=$(($RANDOM % 7)):$(($RANDOM % 60))
		echo "[INFO] Backup would have started at $start_time every day"
		run_backup
	else
		# Run everyday at $start_time
		start_time=$(($RANDOM % 7)):$(($RANDOM % 60))
		echo "[INFO] Backup will start at $start_time every day"
		while true ; do
			sleep_until $start_time
			run_backup
		done
	fi
else
	echo "[ERROR] Unable to connect to repository"
	exit 1
fi
