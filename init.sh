#!/bin/bash

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "错误: 请以 root 用户运行此脚本！"
  exit 1
fi

# 安装 sudo（如果未安装）
if ! command -v sudo &> /dev/null; then
  echo "安装 sudo ..."
  apt update && apt install -y sudo
else
  echo "sudo 已安装，跳过安装步骤"
fi

# 更新系统包
apt update && apt upgrade -y

# 安装 PostgreSQL (如果未安装)
if ! dpkg -l | grep -q postgresql; then
  echo "安装 PostgreSQL..."
  apt install -y postgresql postgresql-contrib
else
  echo "PostgreSQL 已安装，跳过安装步骤"
fi

# 检查 PostgreSQL 服务是否运行
PG_STATUS=$(systemctl is-active postgresql)
if [ "$PG_STATUS" != "active" ]; then
  echo "错误: PostgreSQL 服务未启动，请先启动 PostgreSQL 服务！"
  exit 1
fi

# 安装完数据库后，切换到 postgres 用户执行后续操作
echo "切换到 postgres 用户进行数据库操作..."
su - postgres -c "
  # 创建数据库用户 admin
  psql -U postgres -c \"CREATE USER admin WITH PASSWORD 'admin';\" || {
    echo '错误: 创建用户失败。'
    exit 1
  }

  # 创建数据库 admin
  psql -U postgres -c \"CREATE DATABASE admin WITH OWNER admin;\" || {
    echo '错误: 创建数据库失败。'
    exit 1
  }

  # 授予数据库权限
  psql -U postgres -c \"GRANT ALL PRIVILEGES ON DATABASE admin TO admin;\" || {
    echo '错误: 授权失败。'
    exit 1
  }

  # 完成配置
  echo 'PostgreSQL 已成功安装并配置完毕，用户名和数据库已创建。'
"

# 安装 ToughRADIUS
echo "正在安装 ToughRADIUS..."
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/talkincode/toughradius/main/installer.sh)"

# 配置 /etc/toughradius.yml
echo "覆盖 /etc/toughradius.yml 配置文件..."
cat > /etc/toughradius.yml <<EOL
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
    port: 9090
    tls: false
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

# 启动 ToughRADIUS 服务
echo "启动 ToughRADIUS 服务..."
systemctl enable toughradius
systemctl start toughradius

# 获取本机 IP 地址
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# 提示用户登录信息
echo "ToughRADIUS 安装并配置完成，服务已启动。"
echo "您可以通过以下信息登录 ToughRADIUS 管理面板："
echo "管理面板访问地址：http://$IP_ADDRESS/"
echo "默认用户名：admin"
echo "默认密码：toughradius"
echo "您可以在浏览器中访问管理面板进行操作。"

# 完成
echo "安装完成！"                  功能已经全部ok了  能不能优化一下  防止中断 

