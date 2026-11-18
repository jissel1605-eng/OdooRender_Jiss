#!/bin/bash
set -euo pipefail

: "${PGHOST:?Falta PGHOST en las variables de Render}"
: "${PGPORT:=5432}"
: "${PGUSER:?Falta PGUSER en las variables de Render}"
: "${PGPASSWORD:?Falta PGPASSWORD en las variables de Render}"
: "${PGDATABASE:?Falta PGDATABASE en las variables de Render}"
: "${ODOO_MASTER_PASSWORD:?Falta ODOO_MASTER_PASSWORD en las variables de Render}"

python3 - <<'PY'
import os
from pathlib import Path
p = Path('/etc/odoo/odoo.conf')
p.write_text(p.read_text().replace('REPLACED_AT_STARTUP', os.environ['ODOO_MASTER_PASSWORD']))
PY

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
  --without-demo=all
)

TABLE_EXISTS="$(PGHOST="$PGHOST" PGPORT="$PGPORT" PGUSER="$PGUSER" PGPASSWORD="$PGPASSWORD" PGDATABASE="$PGDATABASE" psql -tAc "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ir_module_module'" 2>/dev/null | tr -d '[:space:]' || true)"
if [ "$TABLE_EXISTS" != "1" ]; then
  echo "Primera ejecución: inicializando la base de datos Odoo..."
  odoo "${COMMON_ARGS[@]}" --init=base --stop-after-init
fi

echo "Iniciando servidor Odoo en el puerto ${PORT:-10000}..."
exec odoo "${COMMON_ARGS[@]}"
