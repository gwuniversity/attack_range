#!/bin/bash
set -e

openssl req -config configs/attackrange.cnf -new -nodes -x509 -newkey rsa:2048 -sha256 -keyout attackrange.key -out attackrange.cert -days 90

openssl req -config configs/www.cnf -new -nodes -x509 -newkey rsa:2048 -sha256 -keyout www.key -out www.cert -days 90