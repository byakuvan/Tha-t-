# Thaïté

Un jeu de cartes multijoueur (2 à 4 joueurs) inspiré du Tiến lên / Big Two, avec comptes joueurs, crédits, mode pari, et quelques modificateurs de règles optionnels.

## Contenu du dépôt

- `index.html` — le jeu complet (interface, logique de jeu, écrans de connexion/lobby/partie). Fichier unique, autonome (HTML + CSS + JS), sans dépendance à builder.
- `regles.html` — les règles du jeu, illustrées.

## ⚠️ Important : le multijoueur ne fonctionne pas tel quel en dehors de Claude

Ce jeu a été développé et hébergé au départ comme un **Artifact Claude**, une page web qui tourne dans l'environnement de claude.ai. Pour la partie multijoueur (comptes, salons de jeu, synchronisation des cartes en temps réel), le code s'appuie sur une fonctionnalité propre à cet environnement : `window.claude.use('db')`, une petite base de données partagée fournie par la plateforme Claude.

**Cette fonctionnalité n'existe pas en dehors de claude.ai.** Concrètement, si tu ouvres `index.html` tel quel (en local ou hébergé sur GitHub Pages, Netlify, etc.) :

- L'interface s'affiche normalement (écran de connexion, règles, etc.).
- Mais dès qu'on essaie de créer un compte, créer une partie ou en rejoindre une, le jeu affichera un message du type *« Le mode multijoueur n'est pas disponible »* — c'est normal, il n'y a tout simplement plus de base de données derrière.

### Pour rendre le multijoueur fonctionnel ailleurs

Il faut remplacer les appels à `dbNs` (recherche `claude.use('db')` et `dbNs.` dans `index.html`) par un vrai backend externe. Les opérations utilisées sont volontairement simples (lecture/écriture de documents JSON, un verrou court style "lease" pour éviter que deux joueurs écrivent en même temps, et un abonnement pour recevoir les mises à jour en direct) — elles se transposent assez naturellement vers, par exemple :

- **Firebase Firestore** (le plus proche conceptuellement de l'API actuelle : documents, `onSnapshot`, etc.)
- **Supabase** (Postgres + réaltime + auth intégrée)
- un petit serveur maison avec **WebSocket** (Node.js + `ws`, ou Socket.IO)

Les endroits à adapter dans le code sont regroupés :
- `dbNs = await claude.use('db')` (initialisation) — à remplacer par l'initialisation du SDK du backend choisi.
- Les fonctions `createRoom`, `claimSeat`, `joinRoom`, `subscribeRoom`, `mutate`, `mutateAccount`, `hashPassword`/`login`/`register` — toutes les opérations de lecture/écriture sur `rooms/<code>` et `accounts/<clé>`.

Le système de comptes (identifiant + mot de passe, hashé en SHA-256 avec sel, stocké dans la base) n'a lui-même rien de spécifique à Claude — il se transpose tel quel une fois branché sur un vrai stockage.

## Lancer le jeu en local (interface seule, sans multijoueur)

Aucune installation nécessaire : ouvre simplement `index.html` dans un navigateur, ou sers le dossier avec un petit serveur statique, par exemple :

```bash
python3 -m http.server 8000
```

puis va sur `http://localhost:8000/index.html`.

## Héberger sur GitHub Pages

1. Pousse ce dépôt sur GitHub.
2. Dans les paramètres du dépôt, active *GitHub Pages* sur la branche principale (dossier racine).
3. Le jeu sera accessible à l'URL fournie par GitHub — mais avec les mêmes limites décrites ci-dessus tant qu'un vrai backend n'est pas branché.
