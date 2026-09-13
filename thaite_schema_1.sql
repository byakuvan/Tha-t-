-- ============================================================================
-- Thaïté — schéma de base de données (PostgreSQL)
-- ============================================================================
-- Ce script recrée, en SQL relationnel, l'équivalent des deux "collections"
-- actuellement stockées dans la base Claude (window.claude.use('db')) :
--   - accounts/<identifiant>   →  table accounts
--   - rooms/<code>             →  table rooms
--
-- Écrit pour PostgreSQL (donc compatible Supabase tel quel). Adaptable à
-- MySQL/SQLite moyennant quelques ajustements (JSONB → JSON, TIMESTAMPTZ →
-- DATETIME, etc.), mais Postgres est recommandé pour son support natif du
-- JSON et son offre gratuite via Supabase.
--
-- Choix de conception : les champs simples et fréquemment filtrés (identité,
-- statut, hôte, mode…) sont des colonnes normales ; les structures imbriquées
-- et très mouvantes du jeu (mains distribuées, pli en cours, journal de
-- manche…) restent en JSONB, avec exactement les mêmes clés que dans le code
-- JS actuel (index.html) — pour que la traduction du code applicatif reste
-- la plus simple possible.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Table : accounts
-- Équivalent de accounts/<accountKey(username)> dans l'ancienne base.
-- La clé de compte (account_key) est déjà calculée côté app par accountKey() :
-- identifiant en minuscules, sans accents, restreint à [a-z0-9_-].
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
  account_key     TEXT PRIMARY KEY,             -- ex : "linh92" (clé technique, minuscule)
  username        TEXT NOT NULL,                -- ex : "Linh92" (affiché tel que saisi à l'inscription)
  password_hash   TEXT NOT NULL,                -- SHA-256 hex de "salt:motdepasse" (voir hashPassword() côté app)
  salt            TEXT NOT NULL,                -- sel hex aléatoire (16 octets)
  credits         NUMERIC(12,2) NOT NULL DEFAULT 100,
  games_played    INTEGER NOT NULL DEFAULT 0,
  wins            INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Contrôle de concurrence optimiste : à incrémenter à chaque écriture et à
  -- vérifier côté app (remplace le acquire()/lease de l'ancienne base) —
  -- ex. UPDATE accounts SET credits = ..., version = version + 1
  --     WHERE account_key = $1 AND version = $2
  version         INTEGER NOT NULL DEFAULT 1,

  CONSTRAINT accounts_username_not_blank CHECK (btrim(username) <> ''),
  CONSTRAINT accounts_credits_finite CHECK (credits IS NOT NULL)
);

-- Recherche/tri du classement (renderLeaderboardScreen : top 50 par crédits).
CREATE INDEX IF NOT EXISTS idx_accounts_credits ON accounts (credits DESC);


-- ----------------------------------------------------------------------------
-- Table : rooms
-- Équivalent de rooms/<code> dans l'ancienne base.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rooms (
  code                TEXT PRIMARY KEY,          -- code de salon à 4 caractères (randomCode(4))
  host_id             TEXT NOT NULL,             -- identity.playerId de l'hôte
  status              TEXT NOT NULL DEFAULT 'lobby'
                        CHECK (status IN ('lobby','playing','roundend','gameover')),

  -- --- Réglages de la partie (settings dans le code JS) -------------------
  score_limit         INTEGER NOT NULL DEFAULT 100,
  mode                TEXT NOT NULL DEFAULT 'normal' CHECK (mode IN ('normal','pari')),
  mise                NUMERIC(12,2) NOT NULL DEFAULT 0,
  no_finish_on_two    BOOLEAN NOT NULL DEFAULT false,   -- modificateur "Impossible de finir sur un 2"
  grande_catastrophe  BOOLEAN NOT NULL DEFAULT false,   -- modificateur "Grande catastrophe"

  -- --- Sièges : tableau JSON ordonné, 2 à 4 entrées une fois la partie
  -- lancée (4 sièges avec des null pendant le salon d'attente). Chaque
  -- élément occupé a la forme {"playerId": "...", "name": "...", "connected": true}.
  seats               JSONB NOT NULL DEFAULT '[null,null,null,null]'::jsonb,

  -- --- Scores cumulés par siège : {"0": 12, "1": 30, ...}
  scores              JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- --- Manche en cours (null hors partie). Forme :
  -- {
  --   "number": 1,
  --   "hands": { "0": [{"r":"3","s":"S"}, ...], "1": [...], ... },
  --   "turn": 0,
  --   "table": { "combo": null, "ownerSeat": null },
  --   "passedSinceLastPlay": [1,2],
  --   "startingSeat": 0,
  --   "openingPlayDone": false,
  --   "log": [{"seat":0,"text":"a le 3 de pique, ouvre la partie"}, ...]
  -- }
  round               JSONB,

  -- --- Résultat de la dernière manche terminée (affiché sur l'overlay de
  -- fin de manche), et classement final une fois la partie terminée.
  last_round_result   JSONB,
  final_ranking       JSONB,                     -- ex : [2,0,1,3] (index de siège, du 1er au dernier)

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Contrôle de concurrence optimiste (voir remarque sur accounts.version) —
  -- remplace le acquire()/lease utilisé par mutate() dans le code actuel.
  version             INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_rooms_status     ON rooms (status);
CREATE INDEX IF NOT EXISTS idx_rooms_created_at ON rooms (created_at);


-- ----------------------------------------------------------------------------
-- Mise à jour automatique de updated_at à chaque UPDATE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_accounts_updated_at ON accounts;
CREATE TRIGGER trg_accounts_updated_at
  BEFORE UPDATE ON accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_rooms_updated_at ON rooms;
CREATE TRIGGER trg_rooms_updated_at
  BEFORE UPDATE ON rooms
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ----------------------------------------------------------------------------
-- Nettoyage : les salons abandonnés (jamais démarrés, ou plus aucune
-- activité) peuvent être purgés périodiquement, par exemple via une tâche
-- planifiée (cron / Supabase Edge Function) exécutant :
--
--   DELETE FROM rooms WHERE updated_at < now() - INTERVAL '24 hours';
--
-- (laissé en commentaire : à activer volontairement, pas automatique)
-- ----------------------------------------------------------------------------
