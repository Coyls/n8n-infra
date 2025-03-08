#!/bin/bash

# Définir les couleurs pour une meilleure lisibilité
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction pour créer un réseau Docker s'il n'existe pas
create_network_if_not_exists() {
    local network_name=$1
    
    if ! docker network ls | grep -q "$network_name"; then
        echo -e "${CYAN}Création du réseau $network_name...${NC}"
        docker network create "$network_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Réseau $network_name créé avec succès${NC}"
        else
            echo -e "${RED}Erreur lors de la création du réseau $network_name${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}Le réseau $network_name existe déjà${NC}"
    fi
}

# Fonction pour créer un volume Docker s'il n'existe pas
create_volume_if_not_exists() {
    local volume_name=$1
    
    if ! docker volume ls | grep -q "$volume_name"; then
        echo -e "${CYAN}Création du volume $volume_name...${NC}"
        docker volume create "$volume_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Volume $volume_name créé avec succès${NC}"
        else
            echo -e "${RED}Erreur lors de la création du volume $volume_name${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}Le volume $volume_name existe déjà${NC}"
    fi
}

# Fonction pour vérifier si une image Docker existe
check_image_exists() {
    local image_name=$1
    
    if docker image inspect "$image_name" &> /dev/null; then
        return 0  # Image existe
    else
        return 1  # Image n'existe pas
    fi
}

# Fonction pour démarrer un service Docker Compose
start_service() {
    local service_dir=$1
    local service_name=$(basename "$service_dir")
    
    echo -e "${BLUE}=== Démarrage des services dans ${service_name} ===${NC}"
    
    if [ -f "${service_dir}/docker-compose.yml" ]; then
        cd "${service_dir}" || { echo -e "${RED}Impossible d'accéder au répertoire ${service_dir}${NC}"; return 1; }
        
        # Vérifier si un fichier .env existe
        if [ -f ".env" ]; then
            echo -e "${YELLOW}Utilisation du fichier .env pour ${service_name}${NC}"
        else
            echo -e "${YELLOW}Attention: Aucun fichier .env trouvé pour ${service_name}${NC}"
        fi
        
        # Si c'est le service Qdrant, vérifier que l'image personnalisée existe
        if [ "$service_name" = "qdrant" ]; then
            if ! check_image_exists "custom-qdrant:v1.13.4-unprivileged"; then
                echo -e "${RED}ERREUR: L'image custom-qdrant:v1.13.4-unprivileged n'existe pas.${NC}"
                echo -e "${YELLOW}Veuillez construire l'image avec la commande:${NC}"
                echo -e "cd ${BASE_DIR}/custom-images/qdrant && docker build -t custom-qdrant:v1.13.4-unprivileged ."
                return 1
            fi
        fi
        
        # Démarrer les services
        echo -e "${YELLOW}Exécution de 'docker compose up -d' dans ${service_name}...${NC}"
        docker compose up -d
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Services dans ${service_name} démarrés avec succès${NC}"
        else
            echo -e "${RED}Erreur lors du démarrage des services dans ${service_name}${NC}"
        fi
        
        cd - > /dev/null
    else
        echo -e "${RED}Aucun fichier docker-compose.yml trouvé dans ${service_dir}${NC}"
    fi
    
    echo ""
}

# Fonction pour vérifier si un service est prêt
wait_for_service() {
    local container_name=$1
    local max_attempts=$2
    local delay=$3
    
    echo -e "${YELLOW}Attente du démarrage complet de ${container_name}...${NC}"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker ps | grep -q "$container_name"; then
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
            
            # Si le conteneur n'a pas de health check, on considère qu'il est prêt
            if [ -z "$health" ] || [ "$health" = "null" ]; then
                echo -e "${GREEN}${container_name} est démarré (pas de health check)${NC}"
                return 0
            elif [ "$health" = "healthy" ]; then
                echo -e "${GREEN}${container_name} est prêt et en bonne santé${NC}"
                return 0
            fi
        fi
        
        echo -e "${YELLOW}Tentative ${attempt}/${max_attempts}: ${container_name} n'est pas encore prêt, attente de ${delay}s...${NC}"
        sleep $delay
        ((attempt++))
    done
    
    echo -e "${RED}Délai d'attente dépassé pour ${container_name}${NC}"
    return 1
}

# Chemin du répertoire de base (où se trouve ce script)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Démarrage de l'infrastructure Project Silicate ===${NC}"
echo -e "${YELLOW}Répertoire de base: ${BASE_DIR}${NC}"
echo ""

# Création des réseaux externes s'ils n'existent pas
echo -e "${BLUE}=== Vérification et création des réseaux Docker ===${NC}"
create_network_if_not_exists "traefik_proxy"
create_network_if_not_exists "project_silicate"
echo ""

# Création des volumes externes s'ils n'existent pas
echo -e "${BLUE}=== Vérification et création des volumes Docker ===${NC}"
create_volume_if_not_exists "traefik_data"
# ?? create_volume_if_not_exists "n8n_data"
echo ""

# Ordre de démarrage (infrastructure d'abord, puis services applicatifs)

# 1. Démarrer traefik (reverse proxy) en premier
start_service "${BASE_DIR}/traefik"
wait_for_service "traefik" 10 10

# 2. Démarrer monitoring (service de surveillance)
start_service "${BASE_DIR}/monitoring"
wait_for_service "autoheal" 5 5

# 3. Démarrer postgres (service de base de données)
start_service "${BASE_DIR}/postgres"
wait_for_service "postgres_db" 15 5

# 4. Démarrer qdrant (service de base de données vectorielle)
start_service "${BASE_DIR}/qdrant"
wait_for_service "qdrant" 10 10

# 5. Démarrer n8n (service applicatif) en dernier
# ?? start_service "${BASE_DIR}/n8n"

echo -e "${GREEN}=== Tous les services ont été démarrés ===${NC}"

# Afficher l'état des conteneurs pour vérification
echo -e "${YELLOW}Conteneurs en cours d'exécution :${NC}"
docker ps

echo -e "${GREEN}Démarrage terminé !${NC}"
