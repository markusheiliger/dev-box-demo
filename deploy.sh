#!/bin/bash

RESET='false'
DUMP='false'

usage() { 
	echo "Usage: $0"
	echo "======================================================================================"
	echo " -o [REQUIRED] 	The organization (DevCenter) name"
	echo " -p [REQUIRED] 	The project name"
	echo " -d [FLAG] 		Dump the BICEP template in ARM format"
	echo " -r [FLAG] 		Reset the full demo environment"
	exit 1; 
}

resetSubscription() {

	local SUBSCRIPTIONID="$1"

	# delete developer cloud related resources
	# ------------------------------------------------------------------------------

	for POOLID in $(az resource list --subscription $SUBSCRIPTIONID --resource-type 'Microsoft.DevCenter/projects/pools' --query [].id -o tsv | dos2unix); do
		echo "$SUBSCRIPTIONID - Deleting devbox pool '$POOLID' ..." \
			&& az resource show --ids $POOLID > /dev/null 2>&1 \
			&& az devcenter admin pool wait --ids $POOLID --created --only-show-errors
	done 

	# delete subscription resources and resource groups
	# ------------------------------------------------------------------------------

	for DEPLOYMENTNAME  in $(az deployment sub list --subscription $SUBSCRIPTIONID --query '[?properties.provisioningState==`InProgress`].name' -o tsv | dos2unix); do
		echo "$SUBSCRIPTIONID - Canceling deployment '$DEPLOYMENTNAME' ..."
		az deployment sub cancel --subscription $SUBSCRIPTIONID --name $DEPLOYMENTNAME -o none &
	done; wait

	for RESOURCEGROUP in $(az group list --subscription $SUBSCRIPTIONID --query '[?properties.provisioningState==`Succeeded`].name' -o tsv | dos2unix); do
		for DEPLOYMENTNAME  in $(az deployment group list --subscription $SUBSCRIPTIONID --resource-group $RESOURCEGROUP --query '[?properties.provisioningState==`InProgress`].name' -o tsv | dos2unix); do
			echo "$SUBSCRIPTIONID - Canceling deployment '$DEPLOYMENTNAME' in resource group '$RESOURCEGROUP' ..."
			az deployment group cancel --subscription $SUBSCRIPTIONID --resource-group $RESOURCEGROUP --name $DEPLOYMENTNAME -o none &
		done; wait
		if [ $(az resource list --subscription $SUBSCRIPTIONID --resource-group $RESOURCEGROUP --query '[] | length(@)' -o tsv) -gt 0 ]; then
			echo "$SUBSCRIPTIONID - Deleting resource group '$RESOURCEGROUP' content ..."
			az deployment group create --mode Complete --resource-group $RESOURCEGROUP --name $"$(uuidgen)" --template-uri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/100-blank-template/azuredeploy.json -o none &
		fi
	done; wait

	for RESOURCEGROUP in $(az group list --subscription $SUBSCRIPTIONID --query '[].name' -o tsv | dos2unix); do 
		echo "$SUBSCRIPTIONID - Deleting resource group '$RESOURCEGROUP' ..." 
		az group delete --subscription $SUBSCRIPTIONID --name $RESOURCEGROUP --yes -o none &
	done; wait

	for DEPLOYMENTNAME in $(az deployment sub list --subscription $SUBSCRIPTIONID --query [].name -o tsv | dos2unix); do
		echo "$SUBSCRIPTIONID - Deleting deployment '$DEPLOYMENTNAME' ..." 
		az deployment sub delete --subscription $SUBSCRIPTIONID --name $DEPLOYMENTNAME -o none &
	done; wait
	
	for ASSIGNMENTID in $(az role assignment list --subscription $SUBSCRIPTIONID --query "[?(principalType=='ServicePrincipal' && principalName=='')].id" -o tsv | dos2unix); do
		echo "Deleting orphan role assignment $ASSIGNMENTID"
		az role assignment delete --subscription $SUBSCRIPTIONID --ids $ASSIGNMENTID --yes -o none &
	done; wait

	for DEFINITIONNAME in $(az role definition list --custom-role-only --scope /subscriptions/$SUBSCRIPTIONID --query [].name -o tsv | dos2unix); do
		echo "Deleting custom role definition $DEFINITIONNAME"
		az role definition delete --name $DEFINITIONNAME --custom-role-only --scope /subscriptions/$SUBSCRIPTIONID -o none &
	done; wait

	# purge resources in soft-delete state
	# ------------------------------------------------------------------------------

	for KEYVAULT in $(az keyvault list-deleted --subscription $SUBSCRIPTIONID --query [].name -o tsv 2>/dev/null | dos2unix); do
		echo "$SUBSCRIPTIONID - Purging deleted key vault '$KEYVAULT' ..." 
		az keyvault purge --subscription $SUBSCRIPTIONID --name $KEYVAULT -o none &
	done; wait

	for APPCONFIG in $(az appconfig list-deleted --subscription $SUBSCRIPTIONID --query [].name -o tsv 2>/dev/null | dos2unix); do
		echo "$SUBSCRIPTIONID - Purging deleted app configuration '$APPCONFIG' ..." 
		az appconfig purge --subscription $SUBSCRIPTIONID --name $APPCONFIG --yes -o none &
	done; wait
}

while getopts 'o:p:dr' OPT; do
    case "$OPT" in
		o)
			ORGANIZATION="${OPTARG}" ;;
		p)
			PROJECT="${OPTARG}" ;;
		d)
			DUMP='true' ;;
        r) 
			RESET='true' ;;
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

if [ "$RESET" = 'true' ]; then

	RESETSUBSCRIPTIONS=( "$SUBSCRIPTION" )

	for PROJECTID in $(az resource list --resource-type 'Microsoft.DevCenter/projects' --query '[].id' -o tsv | dos2unix); do
		for DEPLOYMENTTARGETID in $(az rest --method get --uri "https://management.azure.com$PROJECTID/environmentTypes?api-version=2022-09-01-preview" | jq --raw-output '.. | .deploymentTargetId? | select(. != null)' | dos2unix); do
			RESETSUBSCRIPTIONS+=( "${DEPLOYMENTTARGETID##*/}" ) # <== get the subscription id from the subscription resource id
		done
	done

	for RESETSUBSCRIPTION in "${RESETSUBSCRIPTIONS[@]}"; do
		resetSubscription $RESETSUBSCRIPTION &		
	done; wait

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
