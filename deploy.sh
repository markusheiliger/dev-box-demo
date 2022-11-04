#!/bin/bash

RESET='false'

usage() { 
	echo "Usage: $0"
	echo " -r [FLAG] Reset the target subscription"
	exit 1; 
}

while getopts 'o:p:r' OPT; do
    case "$OPT" in
		o)
			ORGANIZATION="${OPTARG}" ;;
		p)
			PROJECT="${OPTARG}" ;;
        r) 
			RESET='true' ;;
		*) 
			usage ;;
    esac
done

clear

[ ! -f "$ORGANIZATION" ] \
	&& echo "Could not find organization definition file: $ORGANIZATION" \
	&& exit 1

[ ! -f "$PROJECT" ] \
	&& echo "Could not find project definition file: $PROJECT" \
	&& exit 1

az account set --subscription 4e1bd84c-4a2c-4b00-8392-cd0f8b354000 -o none \
	&& echo "Selected subscription $(az account show --query name)"

if [ "$RESET" = 'true' ]; then

	for RESOURCEGROUP in $(az group list --query [].name -o tsv | dos2unix); do
		echo "Deleting resource group '$RESOURCEGROUP' ..."
		az group delete --name $RESOURCEGROUP --no-wait --yes
	done

	echo -n "Waiting for resource group cleanup ..."

	while [ ! -z "$(az group list --query [].name -o tsv | dos2unix)" ]; do
		echo -n "." && sleep 5
	done && echo " done"

fi

UPN=$(grep -Eom1 "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" $PROJECT)

while [ ! -z "$UPN" ]; do

	echo "Resolving UPN '$UPN' ..."
	OID=$(az ad user show --id $UPN --query id -o tsv | dos2unix)

	[ -z "$OID" ] && exit 1

	echo "Replacing UPN '$UPN' with OID '$OID'..."
	sed -i "s/$UPN/$OID/" $PROJECT

	UPN=$(grep -Eom1 "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" $PROJECT)

done

az bicep build --file ./resources/main.bicep --outfile ./deploy.json

az deployment sub create \
	--name $(uuidgen) \
	--location $(jq --raw-output .location $ORGANIZATION) \
	--template-file ./resources/main.bicep \
	--parameters \
		OrganizationJson=@$ORGANIZATION \
		ProjectJson=@$PROJECT \
		Windows365PrinicalId=$(az ad sp show --id 0af06dc6-e4b5-4f28-818e-e78e62d137a5 --query id -o tsv | dos2unix)
