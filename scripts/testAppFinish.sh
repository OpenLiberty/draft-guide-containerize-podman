#!/bin/bash
set -euxo pipefail

##############################################################################
##
##  Travis CI test script
##
##############################################################################

cd ../finish

mvn -Dhttp.keepAlive=false \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 \
    -q clean package
    
podman pull -q icr.io/appcafe/open-liberty:full-java11-openj9-ubi
podman pull -q icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi

podman build -t system -f ./system/Containerfile-full system/.
podman build -t inventory -f ./inventory/Containerfile-full inventory/.
podman build -t system-optimized system/.
podman build -t inventory-optimized inventory/.

podman images -f "label=org.opencontainers.image.authors=Your Name" | grep system
podman images -f "label=org.opencontainers.image.authors=Your Name" | grep inventory
podman images -f "label=org.opencontainers.image.authors=Your Name" | grep system-optimized
podman images -f "label=org.opencontainers.image.authors=Your Name" | grep inventory-optimized

podman run -d --name system -p 9080:9080 system
podman run -d --name inventory -p 9081:9081 inventory
podman run -d --name system-optimized -p 9082:9080 system-optimized
podman run -d --name inventory-optimized -p 9083:9081 inventory-optimized

sleep 120

systemStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://localhost:9080/system/properties/")"
inventoryStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://localhost:9081/inventory/systems/")"
systemOptimizedStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://localhost:9082/system/properties/")"
inventoryOptimizedStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://localhost:9083/inventory/systems/")"

if [ "$systemStatus" == "200" ] && [ "$inventoryStatus" == "200" ] \
  && [ "$systemOptimizedStatus" == "200" ] && [ "$inventoryOptimizedStatus" == "200" ]
then
  echo ENDPOINT OK
else
  echo inventory status:
  echo "$inventoryStatus"
  echo system status:
  echo "$systemStatus"
  echo inventory kernel-slim status:
  echo "$inventoryOptimizedStatus"
  echo system kernel-slim status:
  echo "$systemOptimizedStatus"
  echo ENDPOINT
  exit 1
fi

podman stop inventory
podman rm inventory
podman run -d --name inventory -e http.port=9091 -p 9091:9091 inventory

sleep 30

inventoryStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://localhost:9091/inventory/systems/")"

if [ "$inventoryStatus" == "200" ]
then
  echo ENDPOINT OK
else
  echo inventory status:
  echo "$inventoryStatus"
  echo ENDPOINT
  exit 1
fi

podman exec system cat /logs/messages.log | grep product
podman exec system cat /logs/messages.log | grep java
podman exec system-optimized cat /logs/messages.log | grep product
podman exec system-optimized cat /logs/messages.log | grep java
podman exec inventory cat /logs/messages.log | grep product
podman exec inventory cat /logs/messages.log | grep java
podman exec inventory-optimized cat /logs/messages.log | grep product
podman exec inventory-optimized cat /logs/messages.log | grep java

podman stop inventory system inventory-optimized system-optimized
podman rm inventory system inventory-optimized system-optimized
