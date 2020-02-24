#!/usr/bin/env bash
echo "Build the docker image"
#sudo docker build -t postgresql .
echo "Run a container"
sudo docker run --restart always  --name pg-docker -e POSTGRES_PASSWORD=docker -d -p 5432:5432 -v $HOME/docker/volumes/postgres:/var/lib/postgresql/data postgres
