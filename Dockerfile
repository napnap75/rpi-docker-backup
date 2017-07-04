# Builder image
FROM napnap75/rpi-alpine-base:latest as builder

# Download the required software
RUN apk add --no-cache curl jq \
	&& DOWNLOAD_URL=$(curl -s https://api.github.com/repos/restic/restic/releases/latest | jq -r '.assets[].browser_download_url' | grep "linux_arm\.") \
	&& curl -L -o restic.bz2 ${DOWNLOAD_URL} \
	&& bunzip2 restic.bz2 \
	&& chmod +x restic

# Final image
FROM napnap75/rpi-alpine-base:latest

# Download the required software
RUN apk add --no-cache openssh-client

# Define default command
COPY --from=builder restic /usr/bin
COPY docker-backup.sh /usr/bin
CMD ["/usr/bin/docker-backup.sh"]
