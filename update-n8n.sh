#!/bin/bash
# Script de mise à jour automatique pour n8n

set -euo pipefail

N8N_DIR="/home/coyls/n8n-infra/n8n"
LOG_DIR="$N8N_DIR/update-logs"
LOG_FILE="$LOG_DIR/n8n-update-$(date +\%Y\%m\%d-\%H\%M\%S).log"
SYSTEM_LOG="/var/log/n8n-update.log"

mkdir -p "$LOG_DIR"

OPERATION_ID="OP-$(date +%s)-$(printf '%04x' $RANDOM)"
SERVICE_CONTEXT="n8n-updater"

GRAY='\033[0;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BRIGHT_RED='\033[1;31m'
BLINK='\033[5m'
NC='\033[0m'

log() {
    local level=$1
    local message=$2
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local color=$GREEN
    local log_to_stderr=false
    local log_to_syslog=false
    
    case $level in
        "TRACE")
            color=$GRAY
            ;;
        "DEBUG")
            color=$BLUE
            ;;
        "INFO")
            color=$GREEN
            ;;
        "NOTICE")
            color=$GREEN
            ;;
        "WARNING")
            color=$YELLOW
            log_to_stderr=true
            ;;
        "ERROR")
            color=$RED
            log_to_stderr=true
            ;;
        "CRITICAL")
            color="${BRIGHT_RED}"
            log_to_stderr=true
            log_to_syslog=true
            ;;
        "ALERT")
            color="${BRIGHT_RED}${BLINK}"
            log_to_stderr=true
            log_to_syslog=true
            ;;
        "EMERGENCY")
            color="${BRIGHT_RED}${BLINK}"
            log_to_stderr=true
            log_to_syslog=true
            ;;
    esac
    
    local formatted_message="${timestamp} [${level}] [${OPERATION_ID}] [${SERVICE_CONTEXT}] ${message}"
    
    if [ "$log_to_stderr" = true ]; then
        echo -e "${color}${formatted_message}${NC}" >&2
    else
        echo -e "${color}${formatted_message}${NC}"
    fi
    
    echo "${formatted_message}" >> "$LOG_FILE"
    
    if [ -w "$(dirname "$SYSTEM_LOG")" ]; then
        echo "${formatted_message}" >> "$SYSTEM_LOG"
    fi
    
    if [ "$log_to_syslog" = true ]; then
        logger -p daemon.crit "${level} [${OPERATION_ID}] [${SERVICE_CONTEXT}] ${message}"
    fi
}

log "INFO" "Démarrage du processus de mise à jour n8n"

cd "$N8N_DIR" || {
    log "ERROR" "Impossible d'accéder au répertoire $N8N_DIR"
    exit 1
}

if ! command -v docker &> /dev/null; then
    log "ERROR" "docker n'est pas installé"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    log "ERROR" "La commande 'docker compose' n'est pas disponible"
    exit 1
fi

CURRENT_VERSION=$(docker compose exec -T n8n n8n --version 2>> "$LOG_FILE" || echo "Inconnu")
log "INFO" "Version actuelle de n8n: $CURRENT_VERSION"

log "INFO" "Vérification des mises à jour disponibles..."
docker compose pull &>> "$LOG_FILE"

LATEST_VERSION=$(docker run --rm docker.n8n.io/n8nio/n8n:latest n8n --version 2>> "$LOG_FILE" || echo "Inconnu")
log "INFO" "Dernière version disponible: $LATEST_VERSION"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    log "INFO" "Aucune mise à jour disponible. n8n est déjà à jour (version $CURRENT_VERSION)."
    log "NOTICE" "Processus de vérification terminé sans mise à jour nécessaire."
    exit 0
fi

log "NOTICE" "Nouvelle version de n8n disponible: $CURRENT_VERSION → $LATEST_VERSION. Démarrage de la mise à jour..."

log "INFO" "Création d'un backup avant la mise à jour..."
BACKUP_DATE=$(date +\%Y\%m\%d-\%H\%M\%S)
mkdir -p "$N8N_DIR/backup"

log "DEBUG" "Configuration des permissions pour le répertoire de backup..."
if ! docker compose exec -T n8n mkdir -p /backup &>> "$LOG_FILE"; then
    log "WARNING" "Impossible de créer le répertoire de backup dans le conteneur"
fi

if ! docker compose exec -T n8n chmod 777 /backup &>> "$LOG_FILE"; then
    log "WARNING" "Impossible de modifier les permissions du répertoire de backup"
fi

if docker compose exec -T n8n n8n export:workflow --all --output=/backup/workflows-backup-$BACKUP_DATE.json &>> "$LOG_FILE"; then
    log "INFO" "Backup des workflows créé avec succès"
else
    log "WARNING" "Problème lors de la création du backup des workflows"
fi

if docker compose exec -T n8n n8n export:credentials --all --output=/backup/credentials-backup-$BACKUP_DATE.json &>> "$LOG_FILE"; then
    log "INFO" "Backup des credentials créé avec succès"
else
    log "WARNING" "Problème lors de la création du backup des credentials"
fi

log "INFO" "Arrêt des conteneurs..."
docker compose down &>> "$LOG_FILE"

log "DEBUG" "Attente de l'arrêt complet des conteneurs..."
sleep 15

if docker ps | grep -q "n8n"; then
    log "WARNING" "Les conteneurs n8n sont toujours en cours d'exécution. Forçage de l'arrêt..."
    docker compose down --timeout 30 &>> "$LOG_FILE"
    sleep 5
fi

log "INFO" "Démarrage des nouveaux conteneurs..."
if docker compose up -d &>> "$LOG_FILE"; then
    log "INFO" "Conteneurs démarrés avec succès"
else
    log "ERROR" "Échec du démarrage des conteneurs"
    exit 1
fi

log "DEBUG" "Attente du démarrage des conteneurs..."
sleep 30
if docker compose ps | grep -q "n8n.*Up"; then
    NEW_VERSION=$(docker compose exec -T n8n n8n --version 2>> "$LOG_FILE" || echo "Inconnu")
    
    if [ "$NEW_VERSION" = "$LATEST_VERSION" ]; then
        log "NOTICE" "Mise à jour réussie! Nouvelle version: $NEW_VERSION"
    else
        log "WARNING" "Version après mise à jour ($NEW_VERSION) différente de la version attendue ($LATEST_VERSION)"
    fi
    
    log "DEBUG" "Nettoyage des anciennes images..."
    if docker images "docker.n8n.io/n8nio/n8n" --format "{{.ID}} {{.Tag}}" | grep -v "latest" | awk '{print $1}' | xargs -r docker rmi &>> "$LOG_FILE"; then
        log "INFO" "Nettoyage des anciennes images terminé"
    else
        log "WARNING" "Problème lors du nettoyage des anciennes images"
    fi
else
    log "CRITICAL" "n8n ne semble pas avoir démarré correctement après la mise à jour"
    log "WARNING" "Restauration de la version précédente..."
    docker compose down &>> "$LOG_FILE"
    if docker compose up -d &>> "$LOG_FILE"; then
        log "NOTICE" "Restauration de la version précédente réussie"
    else
        log "ALERT" "Échec de la restauration de la version précédente. Service potentiellement indisponible!"
    fi
fi

log "NOTICE" "Processus de mise à jour terminé"

exit 0
