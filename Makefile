SHELL := /bin/bash
PATH := $(PATH):.env/bin

.PHONY: install


install:
	python3 -m virtualenv .env
	.env/bin/pip install -U -r requirements.txt
	make setup

install-dev:
	.env/bin/pip install -U -r requirements-dev.txt

setup:
	echo "Creating a postgres docker for Dingo"
	docker run --name dingo-postgres -e POSTGRES_PASSWORD=yoursecretpassword -p 5432:5432 -d postgres
	echo "Wait 5 seconds ..."
	sleep 5
	make setupdb
	echo "Done."

setupdb:
	docker exec -i dingo-postgres psql -U postgres -c "create database dingo"
	docker exec -i dingo-postgres psql -U postgres dingo < repo/tables.sql

dropdb:
	docker exec -i dingo-postgres psql -U postgres -c "drop database dingo"

reloaddb:
	make dropdb
	make setupdb


psql:
	docker exec -it dingo-postgres psql -U postgres dingo


autopep8:
	.env/bin/autopep8 --in-place -a -a -a --recursive .

run:
	.env/bin/gunicorn dingolib.rest.app -w 8 -t 30 --threads 4 -b :5000

test:
	.env/bin/python tests.py

run-dev:
	.env/bin/gunicorn dingolib.rest.app -w 1 --reload --log-level=debug

clean:
	docker stop dingo-postgres
	docker rm dingo-postgres
	rm -rf .env
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info
