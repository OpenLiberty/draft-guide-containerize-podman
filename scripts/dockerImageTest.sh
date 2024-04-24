#!/bin/bash
while getopts t:d: flag; do
    case "${flag}" in
    t) DATE="${OPTARG}" ;;
    d) DRIVER="${OPTARG}" ;;
    *) echo "Invalid option" ;;
    esac
done

echo "Testing latest OpenLiberty Docker image"

sed -i "\#<artifactId>liberty-maven-plugin</artifactId>#a<configuration><install><runtimeUrl>https://public.dhe.ibm.com/ibmdl/export/pub/software/openliberty/runtime/nightly/$DATE/$DRIVER</runtimeUrl></install></configuration>" ../start/system/pom.xml ../start/inventory/pom.xml ../finish/system/pom.xml ../finish/inventory/pom.xml
cat ../start/system/pom.xml ../start/inventory/pom.xml ../finish/system/pom.xml ../finish/inventory/pom.xml

sed -i "s;FROM icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi;FROM cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi;g" system/Containerfile inventory/Containerfile
sed -i "s;RUN features.sh;#RUN features.sh;g" system/Containerfile inventory/Containerfile
cat system/Containerfile inventory/Containerfile
sed -i "s;FROM icr.io/appcafe/open-liberty:full-java11-openj9-ubi;FROM cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi;g" system/Containerfile-full inventory/Containerfile-full
cat system/Containerfile-full inventory/Containerfile-full

echo "$DOCKER_PASSWORD" | sudo podman login -u "$DOCKER_USERNAME" --password-stdin cp.stg.icr.io
sudo podman pull -q "cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi"
sudo echo "build level:"; podman inspect --format "{{ index .Config.Labels \"org.opencontainers.image.revision\"}}" cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi

sudo ../scripts/testAppFinish.sh
sudo ../scripts/testAppStart.sh
