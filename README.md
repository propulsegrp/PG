# Atelier Flow

Application de suivi de la production d'un département créatif : web/PWA pour ordinateur et iPhone, application Android native avec React Native et Expo, base PostgreSQL/Supabase commune.

## Démarrer

Node.js 22 ou supérieur, puis :

```sh
npm ci
npm run dev
```

Application web dans `apps/web`, application native dans `apps/mobile`, règles métier communes dans `packages/core`. Pour Android : `cd apps/mobile && npm start`. Un émulateur Android ou Expo Go compatible avec le SDK 58 permet de tester. Le workflow **Android — APK de test** compile un APK autonome, signé avec une clé de développement, disponible dans ses artefacts après réussite.

```sh
npm test
npm run typecheck
npm run build
```

Le dossier `dist` peut être hébergé comme site statique sur Cloudflare Pages. Le projet contient aussi un manifeste Sites pour l'aperçu privé dans ChatGPT.

## Fonctionnement livré

- Connexion par e-mail et code d'accès ; création initiale de l'administrateur par un lien privé à usage unique.
- Démonstration explicitement séparée : données fictives locales, sélecteur de rôles uniquement en mode démo.
- Clients et services classés en Visuels, Vidéos, Couvertures média ou Autres ; tâches, quantités, échéances, interventions et modifications datées.
- Statistiques générales de tous les collaborateurs pour le super administrateur ; statistiques individuelles pour les collaborateurs. Répartition par catégorie, service et client, filtres de période/client/auteur et export CSV.
- Visa « Vu », « Validé », « Correction demandée », historique et statistiques sans double comptage des retouches.
- Transferts avec motif, point de reprise, autorisation du responsable et confirmation de réception.
- Déclaration quotidienne, y compris absence de tâche, rappel dans l'application.
- Modules, charge estimée et évaluations avec publication individuelle. Le barème sur 20 est un modèle provisoire.
- Comptes et invitations individuels expirant après 48 heures ; mots de passe aléatoires affichés une seule fois au responsable.

## Déploiement Supabase

Les scripts `supabase/schema.sql` et `supabase/accounts.sql` décrivent la structure initiale déjà appliquée au projet sélectionné. **Ne pas les rejouer sur une base déjà initialisée.** Ils sont destinés à une installation neuve. Appliquer ensuite `supabase/service_categories.sql` pour la classification des services et la lecture des catégories. La fonction `supabase/functions/atelier-accounts/index.ts` gère les accès ; elle conserve les clés administratives dans l'environnement serveur. Elle vérifie elle-même l'authentification JWT ou les jetons privés de configuration/inscription.

Le fichier `apps/web/src/backend.ts` et l'application mobile contiennent uniquement l'URL et une clé **publiable** Supabase. Ces valeurs ne sont pas des secrets ; RLS et les contrôles serveur protègent les données.

Le lien de premier démarrage n'est jamais placé dans ce dépôt. Il crée le super administrateur et cesse de fonctionner après utilisation. Les formulaires ne proposent pas de libre inscription sans invitation.

## Limites à traiter avant un déploiement général

- Le périmètre serveur actuel est un seul département. Les managers autorisés ont une visibilité sur ce département.
- La récupération par e-mail, les notifications push et les rappels envoyés lorsque l'application est fermée nécessitent une configuration complémentaire. Les rappels visibles dans l'application sont inclus.
- Les pièces jointes sont désactivées ; aucun bucket de fichiers n'est encore configuré.
- Les congés, jours fériés, synchronisation hors ligne, personnalisation de la marque et permissions permanentes de transfert par personne ne sont pas encore implémentés.
- Les codes sont administrés dans l'interface. Supabase Auth permet techniquement à un utilisateur authentifié d'appeler directement son API de changement de mot de passe ; une interdiction stricte à ce niveau nécessite une configuration Auth supplémentaire.
- Le journal concerne les actions métier et la gestion des comptes. L'historique exhaustif des connexions Auth doit être raccordé aux journaux Auth. Une IP reçue via proxy ne constitue pas une preuve d'identité.
- Android : code natif et workflow de compilation fournis ; un APK n'est disponible qu'après compilation réussie. La signature de développement doit être remplacée avant distribution définitive.
- iPhone : installation PWA depuis Safari. Ce n'est pas une application native iOS.
- Offre gratuite Supabase : quotas et mise en pause possible en cas de faible activité ; aucune garantie de disponibilité permanente.

## Sécurité et sauvegardes

Voir [SECURITY.md](SECURITY.md) et [docs/backup.md](docs/backup.md). Aucun mot de passe, clé service_role, export ou jeton privé ne doit être commité. Le workflow de sauvegarde est préparé mais **non configuré et non planifié** tant que les secrets et un test de restauration ne sont pas fournis.
