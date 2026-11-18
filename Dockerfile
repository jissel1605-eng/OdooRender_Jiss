FROM odoo:20.0

USER root

# Corregir la entrega de archivos almacenados en PostgreSQL
RUN python3 - <<'PY'
import odoo
from pathlib import Path

p = Path(odoo.__file__).parent / "addons/base/models/ir_attachment.py"
s = p.read_text()

old = "elif self.url:"
new = "elif self.url and not self.db_datas:"

if new not in s:
    if old not in s:
        raise SystemExit("No se encontró la línea esperada")
    p.write_text(s.replace(old, new, 1))

print("Corrección aplicada correctamente")
PY

COPY addons/ventas_unicah /mnt/extra-addons/ventas_unicah
COPY config/odoo-render.conf /etc/odoo/odoo.conf
COPY start-render.sh /usr/local/bin/start-render.sh

RUN chown -R odoo:odoo /mnt/extra-addons /etc/odoo/odoo.conf \
    && chmod 755 /usr/local/bin/start-render.sh

USER odoo

CMD ["bash", "/usr/local/bin/start-render.sh"]
