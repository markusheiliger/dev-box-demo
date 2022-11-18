#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_PROC=$$
SYNC='false'

error() {
  echo "$@" >&2
  kill -10 $SCRIPT_PROC
}

usage() { 
	echo "Usage: $0"
	echo "======================================================================================"
	echo " -o [REQUIRED] 	The organization (DevCenter) name"
	echo " -p [REQUIRED] 	The project name"
	echo " -e [REQUIRED] 	The name of the environment definition to use"
	echo " -t [REQUIRED] 	The name of the environment type to deploy into"
	echo " -s [FLAG] 		Synchronize catalogs"
	exit 1; 
}

while getopts 'o:p:e:t:s' OPT; do
    case "$OPT" in
		o)
			ORGANIZATION="${OPTARG}" ;;
		p)
			PROJECT="${OPTARG}" ;;
		e)
			ENVIRONMENT="${OPTARG}" ;;
		t)
			ENVIRONMENTTYPE="${OPTARG}" ;;
		s)
			SYNC='true' ;;
		*) 
			usage ;;
    esac
done

clear

[ -z "$ORGANIZATION" ] && usage
[ -z "$PROJECT" ] && usage
[ -z "$ENVIRONMENT" ] && usage
[ -z "$ENVIRONMENTTYPE" ] && usage

if [ "$SYNC" == "true" ]; then
	RESOURCEGROUP=$(az resource list --resource-type 'Microsoft.DevCenter/devcenters' --name $ORGANIZATION --query '[0].resourceGroup' -o tsv --only-show-errors | dos2unix)
	for CATALOG in $(az devcenter admin catalog list --dev-center-name $ORGANIZATION --resource-group $RESOURCEGROUP --query '[].name' -o tsv --only-show-errors | dos2unix); do
		echo "Synchronizing catalog '$CATALOG' ..." && az devcenter admin catalog sync --dev-center-name $ORGANIZATION --resource-group $RESOURCEGROUP --name $CATALOG --only-show-errors >/dev/null
	done
fi

ENVIRONMENTS=$(az devcenter dev catalog-item list --dev-center $ORGANIZATION --project-name $PROJECT --query [].name -o tsv --only-show-errors | dos2unix)

echo "Validationg environment '$ENVIRONMENT' ..." \
	&& [[ ${ENVIRONMENTS[*]} =~ (^|[[:space:]])"$ENVIRONMENT"($|[[:space:]]) ]] \
	|| error "Environment definition '$ENVIRONMENT' does not exist" 

ENVIRONMENTTYPES=$(az devcenter dev environment-type list --dev-center $ORGANIZATION --project-name $PROJECT --query [].name -o tsv --only-show-errors | dos2unix)

echo "Validating environment type '$ENVIRONMENTTYPE' ..." \
	&& [[ ${ENVIRONMENTTYPES[*]} =~ (^|[[:space:]])"$ENVIRONMENTTYPE"($|[[:space:]]) ]] \
	|| error "Environment type '$ENVIRONMENTTYPE' does not exist"

pushd $SCRIPT_DIR > /dev/null

ENVIRONMENTNAME="$ENVIRONMENT-$(date +%s%N)"

echo "Provisioning environment instance '$ENVIRONMENTNAME' ..." \
	&& az devcenter dev environment create \
		--only-show-errors \
		--owner $(az ad signed-in-user show --query id -o tsv | dos2unix) \
		--dev-center-name $ORGANIZATION \
		--project-name $PROJECT \
		--catalog-name Demo \
		--catalog-item-name $ENVIRONMENT \
		--environment-type $ENVIRONMENTTYPE \
		--name $ENVIRONMENTNAME \
		--parameters @./environment-$ENVIRONMENT.json