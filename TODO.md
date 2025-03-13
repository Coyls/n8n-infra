# Liste des ajustements à effectuer avant la mise en production

## Configuration n8n
- [ ] Mettre en place un système de backup automatique pour n8n (similaire à postgres-backup)

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
