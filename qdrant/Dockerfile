FROM qdrant/qdrant:v1.13.4-unprivileged

# Passer en utilisateur root pour installer les packages
USER root

# Installer curl et autres utilitaires utiles
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  curl \
  wget \
  netcat-openbsd \
  ca-certificates && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Revenir à l'utilisateur non-privilégié
USER 1000:1000
