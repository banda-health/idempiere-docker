FROM eclipse-temurin:17-jdk AS builder

ENV IDEMPIERE_HOME /opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME $IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME $IDEMPIERE_HOME/log

WORKDIR $IDEMPIERE_HOME

# Install iDempiere
COPY idempiere/idempiere.build.gtk.linux.x86_64.tar.gz /tmp/idempiere/
RUN tar -zxf /tmp/idempiere/idempiere.build.gtk.linux.x86_64.tar.gz --directory /tmp/idempiere && \
    mv /tmp/idempiere/x86_64/* $IDEMPIERE_HOME && \
    rm -rf /tmp/idempiere

# Copy over shell script
COPY idempiere-server.sh .

FROM eclipse-temurin:17-jdk AS idempiere
WORKDIR /

# Handle Postgresql APT repository updates
RUN sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

RUN apt-get update && \
    apt-get install -y --no-install-recommends nano postgresql-client telnet && \
    rm -rf /var/lib/apt/lists/*

ENV IDEMPIERE_HOME /opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME $IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME $IDEMPIERE_HOME/log

# Copy over iDempiere files
COPY --from=builder $IDEMPIERE_HOME $IDEMPIERE_HOME

# Now set the entrypoint
COPY docker-entrypoint.sh .
COPY health-check.sh .
COPY install-sources.sh .
COPY install-migrations-incrementally.sh .

# Set the entrypoint & commands
HEALTHCHECK --interval=5s --timeout=5s --retries=200 --start-period=5s CMD /health-check.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["idempiere", "install-sources"]
