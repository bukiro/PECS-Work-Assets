#!/bin/bash
echo "Compiling executables for PECS and PECS-Data-Service in the development folders..."

cd /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS/publish
nexe pecs.js -t linux-x64 --build --verbose
cd /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS-Data-Service/publish
nexe service.js -t linux-x64 --build --verbose

echo "Copying publish folders to Downloads..."
rm -rf /mnt/f/Downloads/pecs_publish
cp -r /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS/publish/ /mnt/f/Downloads/pecs_publish
rm -rf /mnt/f/Downloads/pecs_data_service_publish
cp -r /mnt/f/OneDrive/Personal/Projects/Design/PECS/PECS-Data-Service/publish/ /mnt/f/Downloads/pecs_data_service_publish

echo "Deleting custom data from publish folder..."
rm /mnt/f/Downloads/pecs_publish/src/assets/json/*/custom_*.json
rm /mnt/f/Downloads/pecs_publish/src/assets/json/*/*/custom_*.json
rm /mnt/f/Downloads/pecs_publish/src/assets/json/*/extensions.json
rm /mnt/f/Downloads/pecs_publish/src/assets/json/*/*/extensions.json
rm /mnt/f/Downloads/pecs_publish/src/assets/config.json
rm /mnt/f/Downloads/pecs_publish/src/assets/config\ \(demo\).json
rm /mnt/f/Downloads/pecs_publish/src/assets/config\ \(local\).json
rm /mnt/f/Downloads/pecs_publish/server.crt
rm /mnt/f/Downloads/pecs_publish/server.key
rm /mnt/f/Downloads/pecs_data_service_publish/server.crt
rm /mnt/f/Downloads/pecs_data_service_publish/server.key
