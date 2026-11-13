#!/bin/sh
set -e

echo "Running database migrations..."

npm run migrate

echo "Seeding database..."

npm run seed

echo "Starting API..."

exec npm start