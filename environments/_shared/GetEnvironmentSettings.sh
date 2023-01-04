noLabel=\0 

outputJson=$(az appconfig kv list \
	--endpoint "$ConfigurationStore" \
	--auth-mode login \
	--label "$EnvironmentType,$noLabel" \
	--fields key value \
	--only-show-errors 2>&1)

(echo $outputJson | jq -e . >/dev/null 2>&1) \
	&& (echo $outputJson | jq 'map({ (.key|tostring): .value }) | add' > $AZ_SCRIPTS_OUTPUT_PATH) \
	|| (jq -n --arg e "$outputJson" '{error: $e}' > $AZ_SCRIPTS_OUTPUT_PATH)

