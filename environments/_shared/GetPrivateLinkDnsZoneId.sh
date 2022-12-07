#!/bin/bash
DNSZoneId=$(az network private-dns zone show --subscription $Subscription --resource-group $ResourceGroup --name $(echo $DNSZoneName | | tr '[:upper:]' '[:lower:]') --query id -o tsv --only-show-errors 2> /dev/null)
jq -n --arg id "$DNSZoneId" '{ DNSZoneId: $id }' >  $AZ_SCRIPTS_OUTPUT_PATH