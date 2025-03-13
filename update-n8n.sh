#!/bin/bash

# Script de mise à jour automatique pour n8n
# À utiliser dans un cron job

# Activer les options de sécurité
set -euo pipefail

# Définir le chemin vers le répertoire n8n
N8N_DIR="/home/coyls/project-silicate/n8n"

# Définir le chemin pour les logs
LOG_FILE="/home/coyls/project-silicate/n8n/update-logs/n8n-update-$(date +\%Y\%m\%d-\%H\%M\%S).log"
SYSTEM_LOG="/var/log/custom_app.log"

# Créer le répertoire de logs s'il n'existe pas
mkdir -p "/home/coyls/project-silicate/n8n/update-logs"

# Générer un identifiant unique pour cette exécution
OPERATION_ID="OP-$(date +%s)-$(printf '%04x' $RANDOM)"
SERVICE_CONTEXT="n8n-updater"

# Couleurs pour les messages
GRAY='\033[0;37m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BRIGHT_RED='\033[1;31m'
BLINK='\033[5m'
NC='\033[0m' # No Color

# Fonction pour logger les messages
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
    
    # Format standardisé du message
    local formatted_message="${timestamp} [${level}] [${OPERATION_ID}] [${SERVICE_CONTEXT}] ${message}"
    
    # Affichage coloré dans le terminal
    if [ "$log_to_stderr" = true ]; then
        echo -e "${color}${formatted_message}${NC}" >&2
    else
        echo -e "${color}${formatted_message}${NC}"
    fi
    
    # Enregistrement dans le fichier de log local
    echo "${formatted_message}" >> "$LOG_FILE"
    
    # Enregistrement dans le fichier de log système
    if [ -w "$(dirname "$SYSTEM_LOG")" ]; then
        echo "${formatted_message}" >> "$SYSTEM_LOG"
    fi
    
    # Envoi à syslog pour les niveaux critiques
    if [ "$log_to_syslog" = true ]; then
        logger -p daemon.crit "${level} [${OPERATION_ID}] [${SERVICE_CONTEXT}] ${message}"
    fi
}

# En-tête
log "INFO" "Démarrage du processus de mise à jour n8n"

# Aller dans le répertoire n8n
cd "$N8N_DIR" || {
    log "ERROR" "Impossible d'accéder au répertoire $N8N_DIR"
    exit 1
}

# Vérifier si docker compose est installé
if ! command -v docker &> /dev/null; then
    log "ERROR" "docker n'est pas installé"
    exit 1
fi

# Vérifier si la commande docker compose fonctionne
if ! docker compose version &> /dev/null; then
    log "ERROR" "La commande 'docker compose' n'est pas disponible"
    exit 1
fi

# Récupérer la version actuelle
CURRENT_VERSION=$(docker compose exec -T n8n n8n --version 2>> "$LOG_FILE" || echo "Inconnu")
log "INFO" "Version actuelle de n8n: $CURRENT_VERSION"

# Tirer la dernière image et vérifier si une mise à jour est disponible
log "INFO" "Vérification des mises à jour disponibles..."
docker compose pull &>> "$LOG_FILE"

# Récupérer la version de la dernière image
# Créer un conteneur temporaire pour vérifier la version
LATEST_VERSION=$(docker run --rm docker.n8n.io/n8nio/n8n:latest n8n --version 2>> "$LOG_FILE" || echo "Inconnu")
log "INFO" "Dernière version disponible: $LATEST_VERSION"

# Comparer les versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    log "INFO" "Aucune mise à jour disponible. n8n est déjà à jour (version $CURRENT_VERSION)."
    log "NOTICE" "Processus de vérification terminé sans mise à jour nécessaire."
    exit 0
fi

log "NOTICE" "Nouvelle version de n8n disponible: $CURRENT_VERSION → $LATEST_VERSION. Démarrage de la mise à jour..."

# Créer un backup avant la mise à jour
log "INFO" "Création d'un backup avant la mise à jour..."
BACKUP_DATE=$(date +\%Y\%m\%d-\%H\%M\%S)
mkdir -p "$N8N_DIR/backup"

# Correction du problème de permissions pour les backups
log "DEBUG" "Configuration des permissions pour le répertoire de backup..."
# S'assurer que le répertoire de backup est accessible par le conteneur
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

# Redémarrer les conteneurs avec la nouvelle image
log "INFO" "Arrêt des conteneurs..."
docker compose down &>> "$LOG_FILE"

# Attendre que tous les conteneurs soient complètement arrêtés
log "DEBUG" "Attente de l'arrêt complet des conteneurs..."
sleep 15

# Vérifier qu'aucun conteneur n'est en cours d'exécution
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

# Attendre que les conteneurs démarrent
log "DEBUG" "Attente du démarrage des conteneurs..."
sleep 30
if docker compose ps | grep -q "n8n.*Up"; then
    NEW_VERSION=$(docker compose exec -T n8n n8n --version 2>> "$LOG_FILE" || echo "Inconnu")
    
    if [ "$NEW_VERSION" = "$LATEST_VERSION" ]; then
        log "NOTICE" "Mise à jour réussie! Nouvelle version: $NEW_VERSION"
    else
        log "WARNING" "Version après mise à jour ($NEW_VERSION) différente de la version attendue ($LATEST_VERSION)"
    fi
    
    # Nettoyer les anciennes images
    log "DEBUG" "Nettoyage des anciennes images..."
    # Supprimer les anciennes images n8n sauf celles avec le tag latest
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
