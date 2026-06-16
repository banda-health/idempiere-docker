FROM eclipse-temurin:17-jdk AS builder

ENV IDEMPIERE_HOME=/opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME=$IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME=$IDEMPIERE_HOME/log

WORKDIR $IDEMPIERE_HOME

# Install iDempiere
COPY idempiere/idempiere.build.gtk.linux.x86_64.tar.gz /tmp/idempiere/
RUN tar -zxf /tmp/idempiere/idempiere.build.gtk.linux.x86_64.tar.gz --directory /tmp/idempiere && \
    mv /tmp/idempiere/x86_64/* $IDEMPIERE_HOME && \
    rm -rf /tmp/idempiere

FROM eclipse-temurin:17-jdk AS idempiere
WORKDIR /

# Set prerequisites to install MS fonts that reports use
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

# Pin PostgreSQL client 16 (matches postgres:16 in compose). Distro postgresql-client
# tracks a newer major on recent Ubuntu bases and pg_restore 17+ fails against PG 16.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates gnupg2 nano telnet ttf-mscorefonts-installer wget && \
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg && \
    . /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client-16 && \
    rm -rf /var/lib/apt/lists/*
RUN fc-cache -fv

ENV IDEMPIERE_HOME=/opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME=$IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME=$IDEMPIERE_HOME/log

# Copy over iDempiere files
COPY --from=builder $IDEMPIERE_HOME $IDEMPIERE_HOME

# Now set the entrypoint
COPY docker-entrypoint.sh .
COPY health-check.sh .
COPY install-sources.sh .
COPY install-migrations-incrementally.sh .

RUN ln -s $IDEMPIERE_HOME/idempiere-server.sh /usr/bin/idempiere

# Set the entrypoint & commands
HEALTHCHECK --interval=5s --timeout=5s --retries=200 --start-period=5s CMD /health-check.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["idempiere", "install-sources"]
