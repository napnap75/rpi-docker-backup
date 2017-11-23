build:
	docker build -t napnap75/rpi-docker-backup:dev .

build-debug:
	docker build -t napnap75/rpi-docker-backup:dev -f Dockerfile.debug .

test-init:
	echo "1234567890" > restic_pass
	mkdir -p backup
	touch backup/file

test-local: test-init
	docker run --rm -v /tmp/restic_repo:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v $(PWD)/restic_pass:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" --name docker-backup-local --label "napnap75.backup.dirs=$(PWD)/backup" -v /var/run/docker.sock:/var/run/docker.sock:ro -v /:/root_fs:ro napnap75/rpi-docker-backup:dev /usr/bin/docker-backup.sh run-once
	docker run --rm -v /tmp/restic_repo:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v $(PWD)/restic_pass:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" --name docker-backup-local napnap75/rpi-docker-backup:dev restic snapshots

test-bash: test-init
	docker run --rm -it -v /tmp/restic_repo:/restic_repo -e "RESTIC_REPOSITORY=/restic_repo" -v $(PWD)/restic_pass:/restic_pass -e "RESTIC_PASSWORD=/restic_pass" --name docker-backup-local --label "napnap75.backup.dirs=$(PWD)/backup" -v /var/run/docker.sock:/var/run/docker.sock:ro -v /:/root_fs:ro napnap75/rpi-docker-backup:dev bash

clean:
	rm -fr restic_pass backup /tmp/restic_repo
