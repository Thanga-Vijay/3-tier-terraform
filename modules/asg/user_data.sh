#!/bin/bash
yum update -y
yum install -y httpd

cat <<EOF > /var/www/html/index.html
<h1>Three Tier App - App Server</h1>
<p>Healthy</p>
EOF

cat <<EOF > /var/www/html/health
OK
EOF

systemctl start httpd
systemctl enable httpd
