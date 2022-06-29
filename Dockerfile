FROM openjdk:11-jdk

ENV IDEMPIERE_HOME /opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME $IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME $IDEMPIERE_HOME/log

WORKDIR $IDEMPIERE_HOME

RUN apt-get update && \
    apt-get install -y --no-install-recommends nano postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Install iDempiere
COPY src/idempiere.build.gtk.linux.x86_64.tar.gz /tmp/idempiere/
RUN tar -zxf /tmp/idempiere/idempiere.build.gtk.linux.x86_64.tar.gz --directory /tmp/idempiere && \
    mv /tmp/idempiere/x86_64/* $IDEMPIERE_HOME && \
    rm -rf /tmp/idempiere

# Copy over shell script
COPY idempiere-server.sh ./
RUN chmod -x idempiere-server.sh

# Now set the entrypoint
WORKDIR /
COPY docker-entrypoint.sh ./
RUN chmod -x docker-entrypoint.sh

# Set the entrypoint & commands
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["idempiere"]
