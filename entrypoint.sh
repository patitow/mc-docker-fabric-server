#!/bin/sh
set -eu

if [ "${EULA:-}" != "true" ] && [ "${EULA:-}" != "TRUE" ]; then
  printf '%s\n' \
    "Defina EULA=true no ambiente para aceitar o EULA da Mojang:" \
    "https://aka.ms/MinecraftEULA" >&2
  exit 1
fi

printf 'eula=true\n' > eula.txt

if [ ! -f "./${SERVER_JAR}" ]; then
  printf '%s\n' \
    "JAR do servidor não encontrado: /data/${SERVER_JAR}" \
    "Coloque o launcher Fabric (.jar) nesta pasta (volume montado em /data)." >&2
  exit 1
fi

exec java -Xms"${MEMORY}" -Xmx"${MEMORY}" -jar "./${SERVER_JAR}" nogui
