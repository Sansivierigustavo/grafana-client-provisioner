#!/bin/bash

CLIENTE=$1
PORTA=$2
DOMINIO=${CLIENTE}grafana.dominio.com

if [ -z "$CLIENTE" ] || [ -z "$PORTA" ]; then
  echo "Uso: ./novo_cliente_grafana.sh cliente porta"
  echo "Exemplo: ./novo_cliente_grafana.sh acme 3002"
  exit 1
fi

echo "Criando Grafana para cliente: $CLIENTE"
echo "Porta: $PORTA"
echo "Domínio: $DOMINIO"

# Clonar config
cp -r /etc/grafana /etc/grafana-$CLIENTE

# Criar diretório de dados
mkdir /var/lib/grafana-$CLIENTE
chown grafana:grafana /var/lib/grafana-$CLIENTE

# Ajustar grafana.ini
sed -i "s|;http_port = 3000|http_port = $PORTA|g" /etc/grafana-$CLIENTE/grafana.ini
sed -i "s|;domain = localhost|domain = $DOMINIO|g" /etc/grafana-$CLIENTE/grafana.ini
sed -i "s|;root_url = %(protocol)s://%(domain)s:%(http_port)s/|root_url = https://$DOMINIO|g" /etc/grafana-$CLIENTE/grafana.ini
sed -i "s|;data = /var/lib/grafana|data = /var/lib/grafana-$CLIENTE|g" /etc/grafana-$CLIENTE/grafana.ini

# Criar serviço systemd
cat <<EOF > /etc/systemd/system/grafana-$CLIENTE.service
[Unit]
Description=Grafana $CLIENTE
After=network.target

[Service]
User=grafana
Group=grafana
Type=simple

ExecStart=/usr/sbin/grafana-server \\
--config=/etc/grafana-$CLIENTE/grafana.ini \\
--homepath=/usr/share/grafana

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Criar virtualhost Apache
cat <<EOF > /etc/apache2/sites-available/$DOMINIO.conf
<VirtualHost *:80>

ServerName $DOMINIO

ProxyPreserveHost On
ProxyPass / http://127.0.0.1:$PORTA/
ProxyPassReverse / http://127.0.0.1:$PORTA/

</VirtualHost>
EOF

# Ativar serviço
systemctl daemon-reload
systemctl enable grafana-$CLIENTE
systemctl start grafana-$CLIENTE

# Ativar site apache
a2ensite $DOMINIO.conf
systemctl reload apache2

echo ""
echo "✅ Grafana criado!"
echo ""
echo "Agora faça:"
echo ""
echo "1️⃣ Criar DNS:"
echo "$DOMINIO → IP_DO_SERVIDOR"
echo ""
echo "2️⃣ Gerar SSL:"
echo "certbot --apache -d $DOMINIO"
echo ""
echo "3️⃣ Acessar:"
echo "https://$DOMINIO"
echo ""

