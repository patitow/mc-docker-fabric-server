FROM eclipse-temurin:25-jre-noble

RUN useradd --system --no-create-home --home /data --shell /usr/sbin/nologin --user-group mc \
  && mkdir -p /data \
  && chown mc:mc /data

WORKDIR /data

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh \
  && chmod 755 /entrypoint.sh \
  && chown mc:mc /entrypoint.sh

USER mc
EXPOSE 25565

ENV MEMORY=4G \
    SERVER_JAR=fabric-server-mc.26.1.2-loader.0.19.2-launcher.1.1.1.jar

ENTRYPOINT ["/entrypoint.sh"]
