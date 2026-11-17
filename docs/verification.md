# Vérifications de la première version

- Compilation TypeScript du web et du mobile.
- Construction web de production avec Vite.
- Export Android Metro/Hermes réussi : 659 modules, bundle natif produit.
- Audit des dépendances de production : aucune vulnérabilité élevée ou critique ; trois avis modérés à suivre.
- Sept tests des règles métier et des statistiques globales : rappels après 18 h en semaine, absence de double comptage, transfert en attente et barème d'évaluation.
- Tests transactionnels Supabase, annulés à la fin : création de client et de tâche, intervention, transfert avec approbation puis réception, retouche et déclaration de journée ; refus de modification de module par un collaborateur et détection d'une version périmée.
- Tests d'accès : compte en attente sans tâche/client visible, tâche d'autrui invisible et non modifiable, modification directe du rôle refusée.
- Analyse Supabase de sécurité : deux informations attendues pour les tables de jetons sans politique utilisateur (accès serveur uniquement).
- Aucune identité ou tâche fictive des tests serveur conservée après les transactions.

La prévisualisation locale n'a pas démarré : le relais de navigateur a expiré. Les vérifications visuelles et les essais sur appareil réel restent à effectuer. La compilation APK est distincte de la vérification TypeScript et dépend de la réussite du workflow Android.

## Statistiques de production

Les tests vérifient le total général de toutes les catégories, les services personnalisés, la séparation des retouches et la contribution par auteur après transfert. Les périodes utilisent les dates de réalisation des interventions et les demandes utilisent la date de début de tâche. La création et la classification de service sont contrôlées par le serveur et réservées aux responsables actifs.
