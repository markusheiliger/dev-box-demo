#!/bin/bash

RESET='false'
DUMP='false'
CLEAN='false'

usage() { 
	echo "Usage: $0"
	echo "======================================================================================"
	echo " -o [REQUIRED] 	The organization (DevCenter) name"
	echo " -p [REQUIRED] 	The project name"
	echo " -d [FLAG] 		Dump the BICEP template in ARM format"
	echo " -r [FLAG] 		Reset the full demo environment"
	echo " -c [FLAG] 		Clean up the subscription mapped to an environment type"
	exit 1; 
}

resetSubscription() {

	local SUBSCRIPTIONID="$1"
	local WAIT4OPERATIONS=0
	
	for POOLID in $(az resource list --subscription $SUBSCRIPTIONID --resource-type 'Microsoft.DevCenter/projects/pools' --query [].id -o tsv | dos2unix); do
		echo "$SUBSCRIPTIONID - Waiting for pool '$POOLID' ..." \
			&& az resource show --ids $POOLID > /dev/null 2>&1 \
			&& az devcenter admin pool wait --ids $POOLID --created --only-show-errors
	done 

	for DEPLOYMENTNAME in $(az deployment sub list --subscription $SUBSCRIPTIONID --query [].name -o tsv | dos2unix); do
		echo "$SUBSCRIPTIONID - Deleting deployment '$DEPLOYMENTNAME' ..." \
			&& az deployment sub delete --subscription $SUBSCRIPTIONID --name $DEPLOYMENTNAME --no-wait
	done

	WAIT4OPERATIONS=0

	for RESOURCEGROUP in $(az group list --subscription $SUBSCRIPTIONID --query [].name -o tsv | dos2unix); do
		WAIT4OPERATIONS=1
		echo "$SUBSCRIPTIONID - Deleting resource group '$RESOURCEGROUP' ..." \
			&& az group delete --subscription $SUBSCRIPTIONID --name $RESOURCEGROUP --no-wait --yes
	done

	if [ $WAIT4OPERATIONS != 0 ]; then
		echo "$SUBSCRIPTIONID - Waiting for resource group deletion ..."
		while [ ! -z "$(az group list --subscription $SUBSCRIPTIONID --query [].name -o tsv | dos2unix)" ]; do sleep 5; done
	fi

	WAIT4OPERATIONS=0

	for KEYVAULT in $(az keyvault list-deleted --subscription $SUBSCRIPTIONID --query [].name -o tsv 2>/dev/null | dos2unix); do
		WAIT4OPERATIONS=1
		echo "$SUBSCRIPTIONID - Purging deleted key vault '$KEYVAULT' ..." \
			&& az keyvault purge --subscription $SUBSCRIPTIONID --name $KEYVAULT --no-wait
	done

	for APPCONFIG in $(az appconfig list-deleted --subscription $SUBSCRIPTIONID --query [].name -o tsv 2>/dev/null | dos2unix); do
		# no need to track operations for waiting as app configs cannot be purged with a no-wait option
		echo "$SUBSCRIPTIONID - Purging deleted app configuration '$APPCONFIG' ..." \
			&& az appconfig purge --subscription $SUBSCRIPTIONID --name $APPCONFIG --yes
	done

	if [ $WAIT4OPERATIONS != 0 ]; then
		echo "$SUBSCRIPTIONID - Waiting for purge operations ..."
		while [ ! -z "$(az keyvault list-deleted --subscription $SUBSCRIPTIONID --query [].name -o tsv 2>/dev/null | dos2unix)" ]; do sleep 5; done
		sleep 60 # give Azure some additional time to get it's state right after all these purges
	fi
}

cleanupRoleDefinitionsAndAssignments() {

	local SUBSCRIPTIONID="$1"

	for ASSIGNMENTID in $(az role assignment list --subscription $SUBSCRIPTIONID --query "[?(principalType=='ServicePrincipal' && principalName=='')].id" -o tsv | dos2unix); do
		echo "Deleting orphan role assignment $ASSIGNMENTID"
		az role assignment delete --subscription $SUBSCRIPTIONID --ids $ASSIGNMENTID --yes
	done

	for DEFINITIONNAME in $(az role definition list --custom-role-only --scope /subscriptions/$SUBSCRIPTIONID --query [].name -o tsv | dos2unix); do
		echo "Deleting custom role definition $DEFINITIONNAME"
		az role definition delete --name $DEFINITIONNAME --custom-role-only --scope /subscriptions/$SUBSCRIPTIONID
	done

}

while getopts 'o:p:drc' OPT; do
    case "$OPT" in
		o)
			ORGANIZATION="${OPTARG}" ;;
		p)
			PROJECT="${OPTARG}" ;;
		d)
			DUMP='true' ;;
        r) 
			RESET='true' ;;
		c) 
			CLEAN='true' ;;
		*) 
			usage ;;
    esac
done

clear

[ -z "$ORGANIZATION" ] && usage
[ -z "$PROJECT" ] && usage

[ ! -f "$ORGANIZATION" ] \
	&& echo "Could not find organization definition file: $ORGANIZATION" \
	&& exit 1

[ ! -f "$PROJECT" ] \
	&& echo "Could not find project definition file: $PROJECT" \
	&& exit 1

SUBSCRIPTION=$(cat ./organization.json | jq -r .subscription)

az account set --subscription $SUBSCRIPTION -o none \
	&& echo "Selected subscription '$(az account show --query name -o tsv | dos2unix)' ($SUBSCRIPTION) as organization home!" \
	|| exit 1

BACKGROUNDPIDS=()

if [ "$CLEAN" = 'true' ] || [ "$RESET" = 'true' ]; then

	for ENVIRONMENTSUBSCRIPTION in $(cat $PROJECT | jq --raw-output '.. | .subscription? // empty' | dos2unix); do
		resetSubscription $ENVIRONMENTSUBSCRIPTION &
		BACKGROUNDPIDS+=( "$!" )
	done

fi

if [ "$RESET" = 'true' ]; then

	RESETSUBSCRIPTIONS+=( "$SUBSCRIPTION" )

	for PROJECTID in $(az resource list --resource-type 'Microsoft.DevCenter/projects' --query '[].id' -o tsv | dos2unix); do
		for DEPLOYMENTTARGETID in $(az rest --method get --uri "https://management.azure.com$PROJECTID/environmentTypes?api-version=2022-09-01-preview" | jq --raw-output '.. | .deploymentTargetId? | select(. != null)' | dos2unix); do
			RESETSUBSCRIPTIONS+=( "${DEPLOYMENTTARGETID##*/}" ) # <== get the subscription id from the subscription resource id
		done
	done

	for RESETSUBSCRIPTION in "${RESETSUBSCRIPTIONS[@]}"; do
		resetSubscription $RESETSUBSCRIPTION &
		BACKGROUNDPIDS+=( "$!" )
	done

fi

for BACKGROUNDPID in "${BACKGROUNDPIDS[@]}"; do
	[ ! -z "$BACKGROUNDPID" ] && wait $BACKGROUNDPID
done

cleanupRoleDefinitionsAndAssignments $SUBSCRIPTION &
BACKGROUNDPIDS=( "$!" )

for ENVIRONMENTSUBSCRIPTION in $(cat $PROJECT | jq --raw-output '.. | .subscription? // empty' | dos2unix); do
	cleanupRoleDefinitionsAndAssignments $ENVIRONMENTSUBSCRIPTION &
	BACKGROUNDPIDS+=( "$!" )
done

for BACKGROUNDPID in "${BACKGROUNDPIDS[@]}"; do
	[ ! -z "$BACKGROUNDPID" ] && wait $BACKGROUNDPID
done

UPN=$(grep -Eom1 "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" $PROJECT)

while [ ! -z "$UPN" ]; do

	echo "Resolving UPN '$UPN' ..."
	OID=$(az ad user show --id $UPN --query id -o tsv | dos2unix)

	[ -z "$OID" ] && exit 1

	echo "Replacing UPN '$UPN' with OID '$OID'..."
	sed -i "s/$UPN/$OID/" $PROJECT

	UPN=$(grep -Eom1 "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" $PROJECT)

done

if [ "$DUMP" = 'true' ]; then
	az bicep build --file ./resources/main.bicep --outfile ./deploy.json
else
	[ -f ./deploy.json ] && rm -f ./deploy.json
fi

echo "Deploying ..." \
	&& az deployment sub create \
		--name $(uuidgen) \
		--location $(jq --raw-output .location $ORGANIZATION) \
		--template-file ./resources/main.bicep \
		--parameters \
			OrganizationDefinition=@$ORGANIZATION \
			ProjectDefinition=@$PROJECT \
			Windows365PrinicalId=$(az ad sp show --id 0af06dc6-e4b5-4f28-818e-e78e62d137a5 --query id -o tsv | dos2unix)
