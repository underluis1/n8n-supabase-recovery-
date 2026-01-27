# Supabase Migrations

Questa directory contiene le migrazioni SQL per Supabase in ordine versionato.

## Naming Convention

```
NNN_descriptive_name.sql
```

Dove:
- `NNN` = numero sequenziale a 3 cifre (001, 002, 003...)
- `descriptive_name` = nome descrittivo con underscore

## Best Practices

### 1. Idempotenza

Tutte le migrazioni devono essere idempotenti:

```sql
-- Buono
CREATE TABLE IF NOT EXISTS my_table (...);
CREATE INDEX IF NOT EXISTS idx_name ON my_table(...);

-- Cattivo
CREATE TABLE my_table (...);  -- Fallisce se esiste già
```

### 2. Pulizia

Usa sempre `--clean` e `--if-exists` per operazioni DROP:

```sql
DROP TABLE IF EXISTS old_table;
```

### 3. Transazioni

Le migrazioni sono eseguite in transazione automatica. Se un comando fallisce, tutto viene rollback.

### 4. Schema Path

Imposta sempre lo schema path all'inizio:

```sql
SET search_path TO app, public;
```

### 5. Commenti

Documenta ogni migrazione:

```sql
-- =============================================================================
-- Migration: 003_add_payments
-- Description: Aggiunge sistema di pagamenti con Stripe
-- Author: Nome Cognome
-- Created: 2024-01-15
-- =============================================================================
```

### 6. Backward Compatibility

Quando possibile, mantieni backward compatibility:

```sql
-- Aggiunta colonna con default (safe)
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;

-- Rimozione colonna (breaking - documentare!)
-- ALTER TABLE users DROP COLUMN old_field;  -- ATTENZIONE!
```

## Applicazione Migrazioni

```bash
# Applica tutte le migrazioni pending
./platform.sh migrate dev

# Visualizza stato
./platform.sh state dev
```

## Testing Migrazioni

Testa sempre in dev prima di applicare a staging/prod:

```bash
# 1. Crea nuova migrazione
nano migrations/supabase/003_my_feature.sql

# 2. Applica in dev
./platform.sh migrate dev

# 3. Testa funzionalità
# ... test manuale o automatico ...

# 4. Se OK, applica a staging
./platform.sh migrate staging

# 5. Poi prod
./platform.sh migrate prod
```

## Rollback

Non esiste rollback automatico. Per rollback:

1. Crea una nuova migrazione che annulla le modifiche
2. Oppure ripristina da backup

```bash
# Esempio rollback via nuova migrazione
# 004_rollback_feature.sql
DROP TABLE IF EXISTS feature_table;
```

## Struttura Migrazione Tipo

```sql
-- =============================================================================
-- Migration: NNN_feature_name
-- Description: Breve descrizione
-- =============================================================================

SET search_path TO app, public;

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS app.my_table (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- altri campi...
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_my_table_field ON app.my_table(field);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE TRIGGER update_my_table_updated_at
    BEFORE UPDATE ON app.my_table
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at_column();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE app.my_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY my_table_select_own
    ON app.my_table
    FOR SELECT
    USING (auth.uid() = user_id);

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

CREATE OR REPLACE FUNCTION app.my_function()
RETURNS void AS $$
BEGIN
    -- logic here
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- COMMENTI
-- =============================================================================

COMMENT ON TABLE app.my_table IS 'Descrizione tabella';
COMMENT ON FUNCTION app.my_function IS 'Descrizione funzione';
```

## Checklist Pre-Produzione

Prima di applicare in produzione:

- [ ] Testata in dev
- [ ] Testata in staging
- [ ] Backup produzione creato
- [ ] Documentazione aggiornata
- [ ] Team notificato
- [ ] Rollback plan pronto
- [ ] Monitoraggio attivo

## Esempi

Vedi file esistenti:
- `001_init_schema.sql` - Setup iniziale
- `002_add_projects.sql` - Aggiunta feature complessa
