FROM mongo:latest

COPY init-mongo-docker.sh /usr/local/bin/init-mongo-docker.sh

RUN chmod +x /usr/local/bin/init-mongo-docker.sh

CMD ["/usr/local/bin/init-mongo-docker.sh"]