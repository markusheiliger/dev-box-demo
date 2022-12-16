# RESULT=$(az appconfig kv list --subscription $Subscription --name $ConfigurationStore --label $EnvironmentType,\0 --fields key value 2> /dev/null)
# [ -z "$RESULT" ] && RESULT='{}'
# echo $RESULT
# echo $RESULT | jq 'map({ (.key|tostring): .value }) | add' >  $AZ_SCRIPTS_OUTPUT_PATH

outputJson=$(jq -n \
                --arg subscription "$Subscription" \
                --arg name "$ConfigurationStore" \
				--arg label "$EnvironmentType" \
                '{subscription: $subscription, name: $name, label: $label}' )

echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH