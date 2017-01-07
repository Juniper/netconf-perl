CONTAINER=netconf-perl
#HUB=

all: build

build: Dockerfile
	cd .. && docker build -f docker/Dockerfile -t $(CONTAINER) .

run:
	docker rm $(CONTAINER) || true
	docker run -ti --rm --name $(CONTAINER)  $(CONTAINER) || true

#push:
#	docker tag $(CONTAINER) $(HUB)/$(CONTAINER)
#	docker push $(HUB)/$(CONTAINER)

clean:
	docker rmi `docker images | grep "^<none>" | awk '{print $$3}'` 2>/dev/null || true
