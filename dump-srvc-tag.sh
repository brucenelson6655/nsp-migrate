# A simple AZ CLI way uf duming out a service tag 
# example : sh ./dump-srvc-tag.sh AzureDatabricksServerless.EastUS2 

TagName=$1

az network list-service-tags --location eastus \
  --query "values[?name=='$TagName'].properties.addressPrefixes" \
  --output json