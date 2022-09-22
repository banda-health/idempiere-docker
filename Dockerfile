FROM openjdk:11-jdk-slim AS builder

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

FROM openjdk:11-jdk-slim AS idempiere
WORKDIR /

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

# Set the entrypoint & commands
HEALTHCHECK --interval=5s --timeout=5s --retries=100 --start-period=5s CMD /health-check.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["./install-sources.sh", "idempiere"]
