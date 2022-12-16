echo $AZ_SCRIPTS_OUTPUT_PATH
az appconfig kv list --subscription $Subscription --name $ConfigurationStore --label $EnvironmentType,\0 --fields key value | jq 'map({ (.key|tostring): .value }) | add' >  $AZ_SCRIPTS_OUTPUT_PATH
cat $AZ_SCRIPTS_OUTPUT_PATH