# Sauvegardes indépendantes

## État

Le workflow `.github/workflows/backup.yml` est préparé, sans secrets ni planification. **Aucune sauvegarde automatique n'est encore active.** Un export JSON depuis la démo n'est pas une sauvegarde de production.

## Configuration

Dans le dépôt GitHub > Settings > Secrets and variables > Actions, renseigner :

- `SUPABASE_DB_URL` : URL de connexion PostgreSQL adaptée au runner, avec SSL et accès réseau autorisé. Un identifiant de sauvegarde dédié est préférable.
- `BACKUP_PASSPHRASE` : phrase de chiffrement longue, dont une copie est conservée hors GitHub.
- `DRIVE_BACKUP_TOKEN` : jeton OAuth rclone pour un compte dédié aux sauvegardes.
- `DRIVE_BACKUP_FOLDER_ID` : identifiant d'un dossier Drive privé.

Exécuter manuellement le workflow, vérifier l'arrivée du fichier chiffré, puis tester une restauration sur un projet de test séparé. Activer ensuite une planification quotidienne. Conserver plusieurs versions (objectif : 7 quotidiennes et 4 hebdomadaires) ; la rotation n'est pas automatisée dans cette première version.

Le fichier contient les schémas applicatifs, Auth et les métadonnées Storage. Les fichiers binaires Storage, les réglages Auth, les secrets Edge et les clés de signature Android doivent être sauvegardés séparément. Les exports Auth contiennent des données sensibles et des empreintes de mots de passe : le chiffrement est indispensable.

## Restauration

Déchiffrer l'archive dans un environnement privé puis inspecter avec `pg_restore --list`. Préparer une base compatible et restaurer avec les filtres adaptés aux schémas Supabase existants ; ne pas exécuter une restauration aveugle sur la production. Recréer les paramètres et secrets, restaurer les fichiers, puis vérifier connexions, rôles, tâches, statistiques et fichiers.

Une sauvegarde quotidienne peut perdre les changements effectués depuis le dernier export. Un service de planification gratuit peut échouer ou se désactiver : surveiller les exécutions. Cette procédure ne garantit pas le maintien en activité de Supabase gratuit.
