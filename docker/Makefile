all: build

build: Dockerfile
	cd .. && docker build -f docker/Dockerfile -t netconf-perl .

run:
	docker run -ti --rm --name netconf-perl netconf-perl

clean:
	docker rmi `docker images | grep "^<none>" | awk '{print $$3}'` 2>/dev/null || true
