#!/bin/bash
while getopts t:d:v: flag; do
    case "${flag}" in
    t) DATE="${OPTARG}" ;;
    d) DRIVER="${OPTARG}" ;;
    v) OL_LEVEL="${OPTARG}";;
    *) echo "Invalid option" ;;
    esac
done

echo "Testing latest OpenLiberty Docker image"

sed -i "\#<artifactId>liberty-maven-plugin</artifactId>#a<configuration><install><runtimeUrl>https://public.dhe.ibm.com/ibmdl/export/pub/software/openliberty/runtime/nightly/$DATE/$DRIVER</runtimeUrl></install></configuration>" ../start/system/pom.xml ../start/inventory/pom.xml ../finish/system/pom.xml ../finish/inventory/pom.xml
cat ../start/system/pom.xml ../start/inventory/pom.xml ../finish/system/pom.xml ../finish/inventory/pom.xml

if [[ "$OL_LEVEL" != "" ]]; then
  sed -i "s;FROM icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi;FROM cp.stg.icr.io/cp/olc/open-liberty-vnext:$OL_LEVEL-full-java11-openj9-ubi;g" system/Dockerfile inventory/Dockerfile
else
  sed -i "s;FROM icr.io/appcafe/open-liberty:kernel-slim-java11-openj9-ubi;FROM cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi;g" system/Containerfile inventory/Containerfile
fi
sed -i "s;RUN features.sh;#RUN features.sh;g" system/Containerfile inventory/Containerfile
sed -i "s;RUN configure.sh;#RUN configure.sh;g" system/Containerfile inventory/Containerfile
cat system/Containerfile inventory/Containerfile
if [[ "$OL_LEVEL" != "" ]]; then
  sed -i "s;FROM icr.io/appcafe/open-liberty:full-java11-openj9-ubi;FROM cp.stg.icr.io/cp/olc/open-liberty-vnext$OL_LEVEL-full-java11-openj9-ubi;g" system/Containerfile-full inventory/Containerfile-full
else
  sed -i "s;FROM icr.io/appcafe/open-liberty:full-java11-openj9-ubi;FROM cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi;g" system/Containerfile-full inventory/Containerfile-full
fi
sed -i "s;RUN configure.sh;#RUN configure.sh;g" system/Containerfile-full inventory/Containerfile-full
cat system/Containerfile-full inventory/Containerfile-full

echo "$DOCKER_PASSWORD" | podman login -u "$DOCKER_USERNAME" --password-stdin cp.stg.icr.io
podman pull -q "cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi"
echo "build level:"; podman inspect --format "{{ index .Config.Labels \"org.opencontainers.image.revision\"}}" cp.stg.icr.io/cp/olc/open-liberty-daily:full-java11-openj9-ubi

../scripts/testAppFinish.sh
../scripts/testAppStart.sh
