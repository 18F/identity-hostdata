setup:
	bin/setup

test: setup
	bundle exec rake spec
