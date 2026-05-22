setup:
	bin/setup

test: setup
	bundle exec rake spec

lint: setup
	bundle exec rubocop
