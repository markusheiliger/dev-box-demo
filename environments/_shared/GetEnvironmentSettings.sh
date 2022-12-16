noLabel=\0

# outputJson=$(az appconfig kv list \
# 	--subscription "$Subscription" \ 
# 	--name "$ConfigurationStore" \
# 	--label "$EnvironmentType,$noLabel" \
# 	--fields key value | jq 'map({ (.key|tostring): .value }) | add')

outputJson=$(jq -n \
	--arg s "$Subscription" \
	--arg n "$ConfigurationStore" \
	--arg l "$EnvironmentType,$noLabel" \
	'{subscription: $s, name: $n, label: $l}' )

echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH
