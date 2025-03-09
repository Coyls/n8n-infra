# Liste des ajustements à effectuer avant la mise en production

## Configuration n8n
- [ ] Ajouter la configuration SMTP pour n8n dans le fichier docker-compose.yml
- [ ] Configurer les variables d'environnement SMTP dans le fichier .env de n8n
- [ ] Supprimer les variables obsolètes (N8N_DEFAULT_OWNER_* et N8N_BASIC_AUTH_*)
- [ ] Clarifier la situation avec Ollama (ajouter le service ou retirer la variable d'environnement)
- [ ] Mettre en place un système de backup automatique pour n8n (similaire à postgres-backup)

## Sécurité
- [ ] Vérifier que tous les fichiers .env sont correctement remplis avec des valeurs sécurisées
- [ ] S'assurer que la variable QDRANT_API_KEY est bien définie dans le fichier .env de Qdrant
- [ ] Vérifier les permissions des volumes montés pour tous les services

## Monitoring et maintenance
- [ ] Considérer l'ajout d'un service de monitoring plus complet (Prometheus/Grafana)
- [ ] Documenter les procédures de backup/restore pour tous les services
- [ ] Créer un script de maintenance pour la rotation des logs et la vérification de l'espace disque

## Tests
- [ ] Tester l'ensemble du déploiement sur un environnement de pré-production
- [ ] Vérifier que tous les services démarrent correctement avec le script project-silicate-start.sh
- [ ] Tester le script project-silicate-stop.sh pour s'assurer que tous les services s'arrêtent proprement
- [ ] Simuler une panne et vérifier que les services redémarrent correctement avec autoheal

## Documentation
- [ ] Documenter l'architecture complète de l'infrastructure
- [ ] Créer un guide de dépannage pour les problèmes courants
- [ ] Documenter les variables d'environnement requises pour chaque service
