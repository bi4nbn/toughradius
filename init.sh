#!/bin/bash

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "错误: 请以 root 用户运行此脚本！"
  exit 1
fi

# 设置脚本在遇到错误时退出
set -euo pipefail

# 更新系统包列表
echo "更新系统包列表..."
apt update

# 安装必要的工具和 PostgreSQL (如果已安装，apt 会跳过)
echo "安装 wget、curl、sudo 和 PostgreSQL..."
apt install -y wget curl sudo postgresql postgresql-contrib

# 确保 PostgreSQL 服务启动
systemctl enable postgresql
if ! systemctl is-active --quiet postgresql; then
  echo "启动 PostgreSQL 服务..."
  systemctl start postgresql
fi

# 切换到 postgres 用户进行数据库操作，使用 createuser 和 createdb 命令以简化
echo "切换到 postgres 用户进行数据库操作..."
su - postgres -c "
  set -euo pipefail

  # 创建数据库用户 admin（如果不存在）
  if ! psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='admin'\" | grep -q 1; then
    createuser admin
    psql -U postgres -c \"ALTER USER admin WITH PASSWORD 'admin';\"
    echo '用户 admin 已创建。'
  else
    echo '用户 admin 已存在，跳过创建。'
  fi

  # 创建数据库 admin（如果不存在）
  if ! psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='admin'\" | grep -q 1; then
    createdb -O admin admin
    echo '数据库 admin 已创建。'
  else
    echo '数据库 admin 已存在，跳过创建。'
  fi

  # 授予数据库权限
  psql -U postgres -c \"GRANT ALL PRIVILEGES ON DATABASE admin TO admin;\"
  echo '权限已授予。'

  # 完成配置
  echo 'PostgreSQL 已成功安装并配置完毕，用户名和数据库已创建。'
"

# 安装 ToughRADIUS（如果未安装）
if ! command -v toughradius &> /dev/null; then
  echo "正在安装 ToughRADIUS..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/talkincode/toughradius/main/installer.sh)"
else
  echo "ToughRADIUS 已安装，跳过安装步骤"
fi

# 配置 /etc/toughradius.yml（备份原有文件，如果存在）
CONFIG_FILE="/etc/toughradius.yml"
if [ -f "$CONFIG_FILE" ]; then
  echo "备份原有配置文件到 ${CONFIG_FILE}.bak"
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
fi

echo "覆盖 /etc/toughradius.yml 配置文件..."
cat > "$CONFIG_FILE" <<EOL
system:
    appid: ToughRADIUS
    location: Asia/Shanghai
    workdir: /var/toughradius
    debug: true
web:
    host: 0.0.0.0
    port: 80
    tls_port: 1817
    secret: 9b6de5cc-0731-1203-xxtt-0f568ac9da37
database:
    type: postgres
    host: 127.0.0.1
    port: 5432
    name: admin
    user: admin
    passwd: admin
    max_conn: 100
    idle_conn: 10
    debug: false
freeradius:
    enabled: true
    host: 0.0.0.0
    port: 1818
    debug: true
radiusd:
    enabled: true
    host: 0.0.0.0
    auth_port: 1812
    acct_port: 1813
    radsec_port: 2083
    radsec_worker: 100
    debug: true
tr069:
    host: 0.0.0.0
    port: 1819
    tls: true
    secret: 9b6de5cc-0731-1203-xxtt-0f568ac9da37
    debug: true
mqtt:
    server: ""
    username: ""
    password: ""
    debug: false
logger:
    mode: development
    console_enable: true
    loki_enable: false
    file_enable: true
    filename: /var/toughradius/toughradius.log
    queue_size: 4096
    loki_api: http://127.0.0.1:3100
    loki_user: toughradius
    loki_pwd: toughradius
    loki_job: toughradius
    metrics_storage: /var/toughradius/data/metrics
    metrics_history: 168
EOL

# 确保 ToughRADIUS 服务启用并启动
echo "启动 ToughRADIUS 服务..."
systemctl daemon-reload  # 重新加载配置以防万一
systemctl enable toughradius
systemctl restart toughradius  # 使用 restart 以确保配置生效

# 提示用户
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "ToughRADIUS 安装并配置完成，服务已启动。"
echo "您可以通过以下信息登录 ToughRADIUS 管理面板："
echo "管理面板访问地址：http://${IP_ADDRESS}/"
echo "默认用户名：admin"
echo "默认密码：toughradius"

# 完成
echo "安装完成！"
