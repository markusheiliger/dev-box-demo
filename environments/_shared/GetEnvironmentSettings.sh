RESULT=$(az appconfig kv list --subscription $Subscription --name $ConfigurationStore --label $EnvironmentType,\0 --fields key value 2> /dev/null)
[ -z "$RESULT" ] && RESULT='{}'
echo $RESULT
echo $RESULT | jq 'map({ (.key|tostring): .value }) | add' >  $AZ_SCRIPTS_OUTPUT_PATH
