.PHONY: dev prod run test setup-remotes sync-upstream deploy smoke

dev: dev-requirements.txt
	pip install -r dev-requirements.txt

prod: requirements.txt
	pip install -r requirements.txt

run: prod
	FLASK_DEBUG=1 FLASK_APP=snappass.main NO_SSL=True venv/bin/flask run

test:
	PYTHONPATH=snappass venv/bin/nosetests -s tests

setup-remotes:
	./scripts/setup_remotes.sh

sync-upstream:
	./scripts/sync_upstream.sh master

deploy:
	./scripts/deploy_remote.sh --ref master

smoke:
	./scripts/smoke_test.sh https://snappass.tutima.com
