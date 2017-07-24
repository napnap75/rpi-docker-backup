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
	# First check the repository
	restic check &> restic_check.log

	# If it is locked, wait and check again
	sleep_time=10
	while grep -q "repository is already locked by" restic_check.log ; do
		echo "[INFO] Repository locked, waiting ... and trying to unlock before trying to check again"
		sleep $(($sleep_time + $RANDOM % 60))
		sleep_time=$(($sleep_time * 2))
		restic unlock
		restic check &> restic_check.log
	done

	# If it does not exist, create it (and ignore any other kind of error)
	if grep -q "Is there a repository at the following location" restic_check.log ; then
		# Wait a random amount of time to make sure two nodes will not try to do it at the same time
		echo "[INFO] Repository not found, waiting a bit before trying to create it ..."
		sleep $(($RANDOM % 300))

		# Check again to make sure it has not been initialised while waiting
		restic check &> restic_check.log
		if grep -q "Is there a repository at the following location" restic_check.log ; then
			# Then manually create it
			echo "[INFO] ... It's time, creating it"
			restic init
			if [ $? -ne 0 ]; then
				echo "[ERROR] Unable to create repository"
				return $?
			fi
		else
			echo "[INFO] ... Repository has been created while waiting so I have nothing to do"
		fi
	fi
	rm restic_check.log

	# Then check the connection to the repository and return an error to stop the script if the check failed
	restic check
	return $?
}

# Backup one directory using Restic
function backup_dir {
	# Check if the dir to backup is mounted as a subdirectory of /root inside this container
	if [ -d "/root_fs$1" ] ; then
		echo "[DEBUG] restic --hostname $2 backup /root_fs$1"
		while true ; do
			restic --hostname $2 backup /root_fs$1 &> restic_check.log
			if [ $? -ne 0 ]; then
				if grep -q "repository is already locked by" restic_check.log ; then 
					echo "[INFO] Repository locked, waiting ... and trying to unlock before trying to backup again"
					sleep $(($RANDOM % 600))
					restic unlock
					continue
				else
					echo "[ERROR] Unable to create repository"
					cat restic_check.log
					return $?
				fi
			else
				cat restic_check.log
				return 0
			fi
		done
	else
		echo "[ERROR] Directory $1 not found. Have you mounted the root fs from your host with the following option : '-v /:/root_fs:ro' ?"
		return -1
	fi
}

# Find all the directories to backup and call backup_dir for each one
function run_backup {
	count_success=0
	count_failure=0
	
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
				backup_dir $dir_name $1
				if [ $? -ne 0 ]; then
					((++count_failure))
				else
					((++count_success))
				fi
			done
		fi

		# Backup the volumes labelled with "napnap75.backup.volumes"
		if $(echo $container | jq ".Labels | has(\"napnap75.backup.volumes\")") ; then
			for volume_name in $(echo $container | jq -r ".Labels | .[\"napnap75.backup.volumes\"]") ; do
				if [ $namespace != "null" ] ; then volume_name="${namespace}_${volume_name}" ; fi
				volume_mount=$(echo $container | jq -r ".Mounts[] | select(.Name==\"$volume_name\") | .Source")
				echo "[INFO] Backing up volume" $volume_name "with mount" $volume_mount "for container" $container_name
				backup_dir $volume_mount $1
				if [ $? -ne 0 ]; then
					((++count_failure))
				else
					((++count_success))
				fi
			done
		fi
	done
	
	if [[ "$SLACK_URL" != "" ]] ; then
		curl -s -X POST --data-urlencode "payload={\"username\": \"rpi-docker-backup\", \"text\": \"Backup finished on host $HOSTNAME : $count_success succeeded, $count_failure failed\"}" $SLACK_URL
	fi
}

# Set the hostname to the node name when used with Docker Swarm
NODE_NAME=$(curl -s --unix-socket /var/run/docker.sock http:/v1.26/info | jq -r ".Name")
if [[ "$NODE_NAME" != "" ]] ; then
	echo "[INFO] Swarm mode detected, using node name $NODE_NAME instead of $HOSTNAME as hostname"
	HOSTNAME="$NODE_NAME"
fi

# When used with SFTP
if [[ "$RESTIC_REPOSITORY" = sftp:* ]] ; then
	# Copy the key and make it readable only by the current user to meet SSH security requirements
	cp $SFTP_KEY /tmp/foreign_host_key
	chmod 400 /tmp/foreign_host_key
	SFTP_KEY=/tmp/foreign_host_key

	# Initialize the SSH config file with the values provided in the environment
	mkdir -p /root/.ssh
	echo "Host $SFTP_HOST" > /root/.ssh/config
	if [[ "$SFTP_PORT" != "" ]] ; then echo "Port $SFTP_PORT" >> /root/.ssh/config ; fi
	echo "IdentityFile $SFTP_KEY" >> /root/.ssh/config
	echo "StrictHostKeyChecking no" >> /root/.ssh/config
fi

# First check the connection and the repository
echo "[INFO] Trying to connect to repository"
check_connection
if [ $? == 0 ] ; then
	if [ "$1" == "run-once" ] ; then
		# Run only once, mainly for tests purpose
		echo "[INFO] Starting backup immediatly"
		run_backup $HOSTNAME
	else
		# Run everyday at $start_time
		start_time=$(($RANDOM % 7)):$(($RANDOM % 60))
		echo "[INFO] Backup will start at $start_time every day"
		while true ; do
			sleep_until $start_time
			run_backup $HOSTNAME
		done
	fi
else
	echo "[ERROR] Unable to connect to repository (error code $?)"
	if [[ "$SLACK_URL" != "" ]] ; then
		curl -s -X POST --data-urlencode "payload={\"username\": \"rpi-docker-backup\", \"text\": \"Unable to connect to repository $RESTIC_REPOSITORY while trying to run the backup on host $HOSTNAME\"}" $SLACK_URL
	fi
	exit 1
fi
