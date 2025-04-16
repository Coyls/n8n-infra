#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

stop_service() {
    local service_dir=$1
    echo -e "${YELLOW}Arrêt des services dans ${service_dir}...${NC}"
    
    if [ -f "${service_dir}/docker-compose.yml" ]; then
        cd "${service_dir}" || { echo -e "${RED}Impossible d'accéder au répertoire ${service_dir}${NC}"; return 1; }
        docker compose down
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Services dans ${service_dir} arrêtés avec succès${NC}"
        else
            echo -e "${RED}Erreur lors de l'arrêt des services dans ${service_dir}${NC}"
        fi
        cd - > /dev/null
    else
        echo -e "${RED}Aucun fichier docker-compose.yml trouvé dans ${service_dir}${NC}"
    fi
    
    echo ""
}

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Arrêt de tous les services Docker Compose ===${NC}"
echo -e "${YELLOW}Répertoire de base: ${BASE_DIR}${NC}"
echo ""

stop_service "${BASE_DIR}/n8n"
stop_service "${BASE_DIR}/qdrant"
stop_service "${BASE_DIR}/postgres"
stop_service "${BASE_DIR}/monitoring"
stop_service "${BASE_DIR}/traefik"

echo -e "${GREEN}=== Tous les services ont été arrêtés ===${NC}"

echo -e "${YELLOW}Conteneurs encore en cours d'exécution :${NC}"
docker ps

echo -e "${GREEN}Terminé !${NC}"
