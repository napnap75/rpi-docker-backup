build:
	docker build -t napnap75/rpi-docker-backup:latest .

test: build
	echo "1234567890" > restic_pass
	mkdir -p backup
	touch backup/file
	docker run --rm -v /tmp/restic_repo:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v $(PWD)/restic_pass:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" --name docker-backup-local --label "napnap75.backup.dirs=$(PWD)/backup" -v /var/run/docker.sock:/var/run/docker.sock:ro -v /:/root_fs:ro napnap75/rpi-docker-backup:latest /usr/bin/docker-backup.sh run-once
	docker run --rm -v /tmp/restic_repo:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v $(PWD)/restic_pass:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" --name docker-backup-local napnap75/rpi-docker-backup:latest restic snapshots
