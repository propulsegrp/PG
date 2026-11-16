# Sécurité

Le code de ce dépôt est public. Les données métier restent dans Supabase et ne doivent jamais être ajoutées au dépôt, aux issues ou aux artefacts publics.

- RLS est activé sur les onze tables `af_*`.
- Aucun accès anonyme aux tables métier, ni aux fonctions d'écriture.
- Un compte en attente ne voit aucune tâche ou donnée client.
- Les rôles sont lus dans une table serveur, jamais dans `user_metadata`.
- Les écritures passent par un point d'entrée qui vérifie rôle, propriétaire, module actif, état du transfert et version de la tâche.
- La date réelle de saisie et l'auteur des interventions sont imposés par le serveur.
- Les collaborateurs n'ont aucun droit SQL d'écriture sur les profils, journaux, modules ou tables métier.
- Les fonctions privilégiées sont dans un schéma non exposé, avec chemin de recherche fixé et authentification explicite. Les enveloppes publiques sont `SECURITY INVOKER`.
- L'application Android conserve sa session dans le stockage sécurisé du système. La version web conserve sa session via le client Supabase : protéger les appareils et se déconnecter sur un poste partagé.
- Les jetons d'invitation et de configuration sont aléatoires, stockés sous forme de hash, à usage unique. Ne jamais partager le lien de configuration initiale avec l'équipe.
- Les secrets de sauvegarde sont des GitHub Actions Secrets, pas des variables publiques ni des fichiers versionnés.

Les deux tables de jetons ont RLS sans politique d'accès utilisateur : accès volontairement réservé au serveur. L'avis informatif Supabase correspondant est attendu.

Avant une diffusion générale : validation fonctionnelle et revue de sécurité, MFA administrateurs, protection supplémentaire contre les abus des endpoints de jetons, politique de rétention des journaux/IP et preuve de restauration. Les limites Auth restantes sont documentées dans le README.

Signaler un problème sensible en privé à l'administrateur ; ne pas publier de données ou de secrets dans une issue.
