FROM openjdk:11-jdk

ENV IDEMPIERE_VERSION 7.1
ENV IDEMPIERE_HOME /opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME $IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME $IDEMPIERE_HOME/log

WORKDIR $IDEMPIERE_HOME

RUN apt-get update && \
    apt-get install -y --no-install-recommends nano postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY idempiere.build.gtk.linux.x86_64.tar.gz /tmp
COPY ./docker-entrypoint.sh ./
COPY ./idempiere-server.sh ./

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["idempiere"]
