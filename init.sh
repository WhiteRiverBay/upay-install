#!/bin/bash

echo "UPay Configuration Initialization"

echo "1 - Generating RSA Key Pair"
# is openssl installed?
if ! [ -x "$(command -v openssl)" ]; then
  echo 'Error: openssl is not installed.' >&2
  echo 'Please install openssl and try again' >&2
  exit 1
fi
openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:4096
openssl rsa -in private.pem -outform PEM -pubout -out ./.config/public.pem
echo "Please keep the private.pem file safe and secure"
echo "public.pem saved in .config successful"

echo "Generating Google Authenticator Secret: "
#is upay installed?
if ! [ -x "$(command -v upay)" ]; then
  echo 'Error: upay is not installed.' >&2
  echo 'Please install upay and try again' >&2
  echo 'You can install upay by running: npm install -g upay-cli' >&2
  exit 1
fi

GA_SECRET=$(upay generate-ga | head -n 2 |tail -n 1 | awk -F' ' '{print$2}')
echo "Google Authenticator Secret: $GA_SECRET"
echo "Generate Notify Secret: "

# is uuidgen installed?
if ! [ -x "$(command -v uuidgen)" ]; then
  echo 'Error: uuidgen is not installed.' >&2
  echo 'Please install uuidgen and try again' >&2
  exit 1
fi

NOTIFY_SECRET==$(uuidgen | sha256sum | head -c 64)

# 从.env.template中读取模板
echo "Generating .env file"
TEMPLATE=$(cat .env.template)

# 替换模板中的变量, 每个变量都是一个被{}包裹的变量名

# 替换{notify_secret}
TEMPLATE=${TEMPLATE//\{notify_secret\}/$NOTIFY_SECRET}

# 替换{ga_secret}
TEMPLATE=${TEMPLATE//\{ga_secret\}/$GA_SECRET}

# 要求用户输入数据库host
echo "Please enter the database host: "
read DB_HOST
TEMPLATE=${TEMPLATE//\{db_host\}/$DB_HOST}

# 要求用户输入数据库port
echo "Please enter the database port: "
read DB_PORT
TEMPLATE=${TEMPLATE//\{db_port\}/$DB_PORT}

# 要求用户输入数据库名
echo "Please enter the database name: "
read DB_NAME
TEMPLATE=${TEMPLATE//\{db_name\}/$DB_NAME}

# 要求用户输入数据库用户名
echo "Please enter the database username: "
read DB_USER
TEMPLATE=${TEMPLATE//\{db_username\}/$DB_USER}

# 要求用户输入数据库密码
echo "Please enter the database password: "
read DB_PASS
TEMPLATE=${TEMPLATE//\{db_password\}/$DB_PASS}

# test db connection
echo "Testing database connection"
if ! mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS -e "SELECT 1"; then
  echo "Database connection failed, please check your database configuration"
  exit 1
fi

echo "Database connection successful"

# create the database if it does not exist
echo "Creating database if it does not exist"
SQL="CREATE DATABASE IF NOT EXISTS $DB_NAME"
mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS -e "$SQL"

# import the database schema
echo "Importing database schema"
mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME < ./init_mysql.sql
echo "Database schema imported successfully"


# redis_host
echo "Please enter the redis host: "
read REDIS_HOST
TEMPLATE=${TEMPLATE//\{redis_host\}/$REDIS_HOST}

# redis_port
echo "Please enter the redis port: "
read REDIS_PORT
TEMPLATE=${TEMPLATE//\{redis_port\}/$REDIS_PORT}

# redis_password
echo "Please enter the redis password (if no password, keep it empty): "
read REDIS_PASS
TEMPLATE=${TEMPLATE//\{redis_password\}/$REDIS_PASS}

# redis_ssl_enabled
echo "Please enter whether redis ssl is enabled (true/false): "
read REDIS_SSL
TEMPLATE=${TEMPLATE//\{redis_ssl_enabled\}/$REDIS_SSL}

# if redis_ssl_enabled is true, then notify user to make sure the redis certificate is in the .config folder
if [ "$REDIS_SSL" == "true" ]; then
  echo "Please make sure the redis certificate is in the .config/ folder before running the server"
  echo "ca.crt, client.p12 in PKCS12 format"
fi

# redis_password
echo "Please enter the redis password (if it is no password, keep it empty): "
read REDIS_PASS
TEMPLATE=${TEMPLATE//\{redis_password\}/$REDIS_PASS}

#telegram_bot_token
echo "Please enter the telegram bot token (if no telegram bot, keep it empty): "
read TELEGRAM_BOT_TOKEN
TEMPLATE=${TEMPLATE//\{telegram_bot_token\}/$TELEGRAM_BOT_TOKEN}

# telegram_chat_id
echo "Please enter the telegram chat id (if no telegram bot, keep it empty): "
read TELEGRAM_CHAT_ID
TEMPLATE=${TEMPLATE//\{telegram_chat_id\}/$TELEGRAM_CHAT_ID}

# default_callback_url
echo "Please enter the default callback url (if no callback url, keep it empty): "
read DEFAULT_CALLBACK_URL
TEMPLATE=${TEMPLATE//\{default_callback_url\}/$DEFAULT_CALLBACK_URL}

# 替换完成后将结果写入.env文件
echo "$TEMPLATE" > .env

echo "Configuration Initialization Successful"