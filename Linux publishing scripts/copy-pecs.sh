#!/bin/bash
echo "Copying the published packages for PECS and PECS-MongoDB-Connector to your home dir for testing..."

rm -rf ./pecs-publish
rm -rf ./pecs-service-publish
cp -rf /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS/publish ~/pecs-publish
cp -rf /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS-Data-Service/publish ~/pecs-service-publish
cp -rf /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS-Data-Service/src/config.json ~/pecs-service-publish/
