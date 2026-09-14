# Thaïté

Un jeu de cartes multijoueur (2 à 4 joueurs) inspiré du Tiến lên / Big Two, avec comptes joueurs, crédits, mode pari, et quelques modificateurs de règles optionnels.

## Contenu du dépôt

- `index.html` — le jeu complet (interface, logique de jeu, écrans de connexion/lobby/partie). Fichier unique, autonome (HTML + CSS + JS), branché sur **Supabase** pour les comptes et les salons multijoueur.
- `regles.html` — les règles du jeu, illustrées.
- `db/schema.sql` — le schéma PostgreSQL à appliquer sur ton projet Supabase (tables `accounts` et `rooms`, réplication temps réel, notes de sécurité).

## Mise en route (Supabase)

Le jeu tournait au départ comme un Artifact Claude, avec une petite base fournie par la plateforme (`window.claude.use('db')`). Cette version-ci a été réécrite pour utiliser **Supabase** à la place — un vrai backend, utilisable en dehors de Claude, avec une offre gratuite. Trois étapes pour la faire tourner :

### 1. Crée un projet Supabase

Sur [supabase.com](https://supabase.com), crée un compte et un nouveau projet (gratuit). Note son mot de passe de base de données quelque part, tu n'en auras normalement plus besoin après cette étape.

### 2. Applique le schéma

Dans le dashboard du projet → **SQL Editor** → colle le contenu de `db/schema.sql` → **Run**.

Ça crée les tables `accounts` et `rooms`, et active la réplication temps réel dessus (`ALTER PUBLICATION supabase_realtime ADD TABLE ...`) — sans cette dernière ligne, le jeu fonctionnerait mais personne ne recevrait jamais la moindre mise à jour en direct (il faudrait recharger la page pour voir un adversaire jouer une carte).

### 3. Renseigne les clés dans `index.html`

Dans le dashboard → **Project Settings → API**, récupère :
- l'**URL du projet** (ex : `https://abcdefgh.supabase.co`)
- la clé **`anon` `public`**

Puis ouvre `index.html`, cherche ce bloc tout en haut du script (recherche `SUPABASE_URL`) et remplace les deux valeurs :

```js
const SUPABASE_URL = 'https://TON-PROJET.supabase.co';
const SUPABASE_ANON_KEY = 'TA_CLE_ANON_PUBLIC';
```

C'est tout — le jeu est fonctionnel, en local ou une fois hébergé (voir plus bas).

## ⚠️ Sécurité : à savoir avant de partager le lien largement

La clé `anon` est faite pour être visible dans le code d'une page (ce n'est pas un secret serveur), mais par défaut, ces deux tables n'ont **aucune restriction d'accès (RLS)** : n'importe qui connaissant l'URL du projet et la clé `anon` — donc n'importe qui ouvrant simplement le jeu — peut en théorie lire ou modifier n'importe quelle ligne des deux tables directement (sans passer par l'interface du jeu), y compris les mots de passe hashés de tous les comptes ou les crédits de n'importe qui.

C'est le même niveau de confiance qu'avait l'ancienne base Claude (pensée pour jouer entre amis, pas comme un vrai service avec de vrais enjeux). Le fichier `db/schema.sql` contient, en commentaire à la fin, des pistes concrètes pour muscler ça (restreindre les colonnes lisibles, vérifier les mots de passe côté serveur via une fonction SQL) si tu veux aller plus loin — demande si tu veux qu'on les mette en place.

## Lancer le jeu en local

Aucune installation nécessaire : ouvre simplement `index.html` dans un navigateur une fois les clés Supabase renseignées, ou sers le dossier avec un petit serveur statique :

```bash
python3 -m http.server 8000
```

puis va sur `http://localhost:8000/index.html`.

## Héberger sur GitHub Pages

1. Pousse ce dépôt sur GitHub (avec tes clés Supabase déjà renseignées dans `index.html` — voir la note de sécurité ci-dessus : ces clés seront visibles publiquement dans le code source si le dépôt est public, ce qui est normal et attendu pour une clé `anon`).
2. Dans les paramètres du dépôt, active *GitHub Pages* sur la branche principale (dossier racine).
3. Le jeu sera accessible à l'URL fournie par GitHub, jouable par n'importe qui, sans compte Claude.
