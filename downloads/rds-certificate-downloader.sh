#!/bin/bash

# parameters
region=$1

# variabales
intermediate_file="rds-ca-2015-${region}.pem"
intermediate_url="https://s3.amazonaws.com/rds-downloads/${intermediate_file}"
root_file="rds-ca-2015-root.pem"
root_url="https://s3.amazonaws.com/rds-downloads/${root_file}"
bundle_file="rds-ca-2015-${region}-bundle.pem"

if [[ $region == '' ]]; then
	echo "region must be specified"
	echo "usage: rds-certificate-downloader.sh eu-central-1"
	exit 1
fi

wget -q $intermediate_url
wget -q $root_url

cat $intermediate_file > $bundle_file
rm $intermediate_file

cat $root_file >> $bundle_file
rm $root_file