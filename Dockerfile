FROM openjdk:11-jdk

ENV IDEMPIERE_VERSION 7.1
ENV IDEMPIERE_HOME /opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME $IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME $IDEMPIERE_HOME/log

WORKDIR $IDEMPIERE_HOME

RUN apt-get update && \
    apt-get install -y --no-install-recommends nano postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY idempiere.build.gtk.linux.x86_64.tar.gz /tmp/idempiere-server.tar.gz

RUN tar -xf /tmp/idempiere-server.tar.gz -d /tmp && \
    mv /tmp/x86_64/* $IDEMPIERE_HOME && \
    rm -rf /tmp/idempiere*
RUN cat $IDEMPIERE_HOME/MD5SUMS
RUN ln -s $IDEMPIERE_HOME/idempiere-server.sh /usr/bin/idempiere

COPY docker-entrypoint.sh $IDEMPIERE_HOME
COPY idempiere-server.sh $IDEMPIERE_HOME

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["idempiere"]
