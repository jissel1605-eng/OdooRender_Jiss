
#!/bin/bash
set -euo pipefail

# Comprobar las variables de conexión de Render
: "${PGHOST:?Falta PGHOST en las variables de Render}"
: "${PGPORT:=5432}"
: "${PGUSER:?Falta PGUSER en las variables de Render}"
: "${PGPASSWORD:?Falta PGPASSWORD en las variables de Render}"
: "${PGDATABASE:?Falta PGDATABASE en las variables de Render}"
: "${ODOO_MASTER_PASSWORD:?Falta ODOO_MASTER_PASSWORD en las variables de Render}"

# Configurar contraseña maestra de Odoo
python3 - <<'PY'
import os
from pathlib import Path

p = Path('/etc/odoo/odoo.conf')
config = p.read_text()
config = config.replace(
    'REPLACED_AT_STARTUP',
    os.environ['ODOO_MASTER_PASSWORD']
)
p.write_text(config)
PY

# Argumentos de inicio de Odoo
COMMON_ARGS=(
  --config=/etc/odoo/odoo.conf
  --db_host="$PGHOST"
  --db_port="$PGPORT"
  --db_user="$PGUSER"
  --db_password="$PGPASSWORD"
  --database="$PGDATABASE"
  --http-interface=0.0.0.0
  --http-port="${PORT:-10000}"
  --proxy-mode
  --workers=0
  --max-cron-threads=0
  --limit-memory-soft=402653184
  --limit-memory-hard=469762048
)

# Comprobar si la base de datos ya está inicializada
TABLE_EXISTS="$(
  PGHOST="$PGHOST" \
  PGPORT="$PGPORT" \
  PGUSER="$PGUSER" \
  PGPASSWORD="$PGPASSWORD" \
  PGDATABASE="$PGDATABASE" \
  psql -tAc "
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema='public'
    AND table_name='ir_module_module'
  " 2>/dev/null | tr -d '[:space:]' || true
)"

# Inicializar Odoo si es la primera ejecución
if [ "$TABLE_EXISTS" != "1" ]; then
  echo "Primera ejecución: inicializando Odoo..."

  odoo "${COMMON_ARGS[@]}" \
    --init=base \
    --stop-after-init
fi

# Configurar almacenamiento de adjuntos en PostgreSQL
echo "Configurando almacenamiento en PostgreSQL..."

PGHOST="$PGHOST" \
PGPORT="$PGPORT" \
PGUSER="$PGUSER" \
PGPASSWORD="$PGPASSWORD" \
PGDATABASE="$PGDATABASE" \
psql -v ON_ERROR_STOP=1 -c "
INSERT INTO ir_config_parameter
    (key, value, create_uid, write_uid, create_date, write_date)
VALUES
    ('ir_attachment.location', 'db', 1, 1, NOW(), NOW())
ON CONFLICT (key)
DO UPDATE SET
    value = 'db',
    write_date = NOW();
"

# Eliminar únicamente los paquetes antiguos de CSS y JavaScript
echo "Limpiando recursos web antiguos..."

PGHOST="$PGHOST" \
PGPORT="$PGPORT" \
PGUSER="$PGUSER" \
PGPASSWORD="$PGPASSWORD" \
PGDATABASE="$PGDATABASE" \
psql -v ON_ERROR_STOP=1 -c "
DELETE FROM ir_attachment
WHERE url LIKE '/web/assets/%';
"

# Iniciar Odoo
echo "Iniciando servidor Odoo en el puerto ${PORT:-10000}..."

exec odoo "${COMMON_ARGS[@]}"
