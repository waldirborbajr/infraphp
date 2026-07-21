configuration.nix

{ config, pkgs, ... }:

{
  # Habilitar serviços
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Configurações globais de performance
    eventsConfig = ''
      worker_connections 4096;
      multi_accept on;
    '';

    appendHttpConfig = ''
      fastcgi_buffers 16 32k;
      fastcgi_buffer_size 64k;
      proxy_buffering on;
    '';
  };

  services.phpfpm = {
    pools.web = {
      user = "nginx";
      group = "nginx";
      phpPackage = pkgs.php83;  # ou pkgs.php84

      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "listen.mode" = "0660";

        # === TUNING PARA SERVIDOR PARRUDO ===
        "pm" = "dynamic";           # ou "static" se quiser máximo desempenho
        "pm.max_children" = "120";     # Ajuste conforme sua RAM (veja abaixo)
        "pm.start_servers" = "30";
        "pm.min_spare_servers" = "20";
        "pm.max_spare_servers" = "60";
        "pm.max_requests" = "800";     # Evita memory leaks

        "request_terminate_timeout" = "120s";
        "pm.status_path" = "/status";
      };

      phpOptions = ''
        upload_max_filesize = 64M
        post_max_size = 64M
        memory_limit = 512M
        max_execution_time = 120
        opcache.enable = 1
        opcache.memory_consumption = 512
        opcache.max_accelerated_files = 100000
        opcache.validate_timestamps = 0   # em produção
      '';
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql16;
    # Ajustes de performance aqui embaixo
    settings = {
      max_connections = "300";
      shared_buffers = "8GB";           # ~25% da RAM
      effective_cache_size = "20GB";
      work_mem = "128MB";
      maintenance_work_mem = "2GB";
      random_page_cost = "1.1";         # se usar SSD/NVMe
      effective_io_concurrency = "300";
    };
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

--------------------------------------------------------------------------------------------------------------

/etc/nixos/nginx/sites/seu-site.nix

services.nginx.virtualHosts."seusite.com" = {
  forceSSL = true;
  enableACME = true;   # ou sslCertificate etc.

  root = "/var/www/seu-site/public";   # ajuste para sua aplicação

  locations."/" = {
    index = "index.php";
    tryFiles = "$uri $uri/ /index.php?$query_string";
  };

  locations."~ \.php$" = {
    fastcgiPass = "unix:/run/phpfpm/web.sock";
    fastcgiParams = {
      SCRIPT_FILENAME = "$document_root$fastcgi_script_name";
    };
    extraConfig = ''
      fastcgi_read_timeout 120s;
    '';
  };

  # Cache de assets estáticos
  locations."~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf)$" = {
    extraConfig = ''
      expires 30d;
      access_log off;
      add_header Cache-Control "public";
    '';
  };
};

--------------------------------------------------------------------------------------------------------------

UBUNTU

1.

sudo apt update
sudo apt install nginx php8.3-fpm php8.3-pgsql php8.3-mbstring php8.3-xml php8.3-curl \
                 php8.3-opcache php8.3-mysql php8.3-redis postgresql postgresql-contrib \
                 redis-server -y

2.                 

sudo nano /etc/php/8.3/fpm/pool.d/www.conf

[www]
user = www-data
group = www-data
listen = /run/php/php8.3-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; ==================== TUNING PARA SERVIDOR PARRUDO ====================
pm = dynamic                    ; ou "static" para picos muito altos
pm.max_children = 120           ; Ajuste conforme sua RAM (veja abaixo)
pm.start_servers = 30
pm.min_spare_servers = 20
pm.max_spare_servers = 60
pm.max_requests = 800           ; Recicla processos (evita memory leak)

request_terminate_timeout = 120s
pm.status_path = /status

; Opcional: slow log
request_slowlog_timeout = 10s
slowlog = /var/log/php8.3-fpm.log

3.

sudo systemctl restart php8.3-fpm

4.

sudo nano /etc/nginx/sites-available/seu-site

server {
    listen 80;
    server_name seu-dominio.com www.seu-dominio.com;

    root /var/www/seu-site/public;     # Ajuste para o caminho da sua aplicação
    index index.php index.html;

    # ===== Performance =====
    client_max_body_size 64M;
    fastcgi_buffers 16 32k;
    fastcgi_buffer_size 64k;
    fastcgi_read_timeout 120s;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Cache agressivo em arquivos estáticos
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff2?|ttf|eot)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }

    # Status do PHP-FPM (opcional)
    location ~ ^/php-status$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        allow 127.0.0.1;
        deny all;
    }
}

5.

sudo ln -s /etc/nginx/sites-available/seu-site /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx

6.

sudo nano /etc/postgresql/16/main/postgresql.conf

7.

shared_buffers = 8GB               # ~25% da RAM
effective_cache_size = 20GB
work_mem = 128MB
maintenance_work_mem = 2GB
max_connections = 300
random_page_cost = 1.1             # SSD/NVMe
effective_io_concurrency = 300

8.

sudo systemctl restart postgresql

9.

sudo systemctl enable --now redis-server

10.

# Reiniciar tudo
sudo systemctl restart nginx php8.3-fpm postgresql redis

# Ver uso de memória dos processos PHP
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head

# Status PHP-FPM
curl http://seusite.com/php-status

--------------------------------------------------------------------------------------------------------------

# 1. Subir os serviços
docker compose up -d --build

# 2. Gerar certificado Let's Encrypt (rode uma vez)
docker compose run --rm certbot certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email seuemail@dominio.com \
  --agree-tos \
  --no-eff-email \
  -d seu-dominio.com -d www.seu-dominio.com