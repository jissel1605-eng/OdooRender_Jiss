FROM odoo:20.0
USER root
COPY addons/ventas_unicah /mnt/extra-addons/ventas_unicah
COPY config/odoo-render.conf /etc/odoo/odoo.conf
COPY start-render.sh /usr/local/bin/start-render.sh
RUN chown -R odoo:odoo /mnt/extra-addons /etc/odoo/odoo.conf && chmod 755 /usr/local/bin/start-render.sh
USER odoo
CMD ["bash", "/usr/local/bin/start-render.sh"]
