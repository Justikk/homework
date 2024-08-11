#!/bin/bash

# Устанавливаем директорию в home
BASE_DIR="$HOME/my_project"
APP_DIR="$BASE_DIR/app"
PGDATA_DIR="$BASE_DIR/pgdata"

# Создаем сеть
NETWORK_NAME="appnetwork"
docker network create $NETWORK_NAME

# Создаем файл 1.env
ENV_FILE="$BASE_DIR/1.env"
mkdir -p $BASE_DIR
cat <<EOL > $ENV_FILE
POSTGRES_DB=mydatabase
POSTGRES_USER=myuser
POSTGRES_PASSWORD=mypassword
POSTGRES_HOST=postgres_container
POSTGRES_PORT=5432
EOL

# Создаем рабочие директории для PostgreSQL и приложения
mkdir -p $APP_DIR
mkdir -p $PGDATA_DIR

# Создаем Flask приложение
cat <<EOL > $APP_DIR/app.py
from flask import Flask, jsonify
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

DB_NAME = os.getenv('POSTGRES_DB')
DB_USER = os.getenv('POSTGRES_USER')
DB_PASSWORD = os.getenv('POSTGRES_PASSWORD')
DB_HOST = os.getenv('POSTGRES_HOST')
DB_PORT = os.getenv('POSTGRES_PORT')

def get_db_connection():
    conn = psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=DB_PORT
    )
    return conn

@app.route('/')
def index():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT version();')
        db_version = cursor.fetchone()
        cursor.close()
        conn.close()
        return jsonify({'status': 'success', 'db_version': db_version})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOL

# Создаем Dockerfile для Flask приложения
cat <<EOL > $APP_DIR/Dockerfile
FROM python:3.9-alpine

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
EOL

# Создаем requirements.txt
cat <<EOL > $APP_DIR/requirements.txt
Flask==2.3.2
psycopg2-binary==2.9.7
python-dotenv==1.0.0
EOL

# Сборка Docker-образа для Flask приложения
docker build -t flask_app $APP_DIR

# Запуск контейнера PostgreSQL
docker run --name postgres_container --env-file $ENV_FILE -v $PGDATA_DIR:/var/lib/postgresql/data --network $NETWORK_NAME -d postgres:latest

# Запуск контейнера Flask
docker run --name flask_container --env-file $ENV_FILE -v $APP_DIR:/app --network $NETWORK_NAME -p 5000:5000 -d flask_app

echo "Контейнеры запущены и подключены к сети $NETWORK_NAME."
echo "Flask приложение доступно по адресу: http://localhost:5000"
