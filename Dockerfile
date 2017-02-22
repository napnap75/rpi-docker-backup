FROM napnap75/rpi-alpine-base:latest

# Install dependencies
RUN apk update \
	&& apk add curl jq py-paramiko py-cryptography py-setuptools duplicity openssh-client \
	&& rm -rf /var/cache/apk/*

# Add a volume for the duplicity archives
VOLUME /root

# Define default command
ADD docker-backup.sh /usr/bin
RUN chmod +x /usr/bin/docker-backup.sh
CMD ["/usr/bin/docker-backup.sh"]
