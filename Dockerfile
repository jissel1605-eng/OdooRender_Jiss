
FROM odoo:20.0

USER root

# Corregir la entrega de archivos almacenados en PostgreSQL
RUN python3 - <<'PY'
import importlib.util
from pathlib import Path

# Localizar la carpeta de Odoo
spec = importlib.util.find_spec("odoo")

if spec is None or not spec.submodule_search_locations:
    raise SystemExit("No se pudo localizar la instalación de Odoo")

odoo_path = Path(next(iter(spec.submodule_search_locations)))
p = odoo_path / "addons/base/models/ir_attachment.py"

if not p.is_file():
    raise SystemExit(f"No se encontró el archivo: {p}")

s = p.read_text()

# Buscar la condición dentro del método correspondiente
method_start = s.find("def _to_http_stream")

if method_start == -1:
    raise SystemExit("No se encontró el método _to_http_stream")

old = "elif self.url:"
new = "elif self.url and not self.db_datas:"

pos = s.find(old, method_start)

if pos != -1:
    s = s[:pos] + new + s[pos + len(old):]
    p.write_text(s)
elif new not in s[method_start:]:
    raise SystemExit("No se encontró la condición que se debe corregir")

print("Corrección de Odoo aplicada correctamente")
PY

COPY addons/ventas_unicah /mnt/extra-addons/ventas_unicah
COPY config/odoo-render.conf /etc/odoo/odoo.conf
COPY start-render.sh /usr/local/bin/start-render.sh

RUN chown -R odoo:odoo /mnt/extra-addons /etc/odoo/odoo.conf \
    && chmod 755 /usr/local/bin/start-render.sh

USER odoo

CMD ["bash", "/usr/local/bin/start-render.sh"]
