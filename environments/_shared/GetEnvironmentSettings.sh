noLabel=\0

outputJson=$(az appconfig kv list \
	--only-show-errors \
	--subscription "$Subscription" \
	--name "$ConfigurationStore" \
	--label "$EnvironmentType,$noLabel" \
	--fields key value 2>&1)

if [jq -e . >/dev/null 2>&1 <<<"$outputJson"]; then	
 	echo $outputJson | jq 'map({ (.key|tostring): .value }) | add' > $AZ_SCRIPTS_OUTPUT_PATH
else
	jq -n --arg e "$outputJson" '{error: $e}' > $AZ_SCRIPTS_OUTPUT_PATH
fi

# outputJson=$(jq -n \
# 	--arg s "$Subscription" \
# 	--arg n "$ConfigurationStore" \
# 	--arg l "$EnvironmentType,$noLabel" \
# 	'{subscription: $s, name: $n, label: $l}' )

# echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH
