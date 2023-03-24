mode=$1
Product='{\"name\":\"medrec1\",\"price\":10,\"desc\":\"description\",\"policy\":{\"location\":\"Sweden\",\"value\":3,\"status\":\"FOR_SALE\"}}'

Policy='{\"location\":\"Italy\",\"value\":90,\"status\":\"FOR_SALE\"}'


echo "$js" | jq -r
# echo Product
# set -x

if [ $mode == "add" ]; then
	peer chaincode invoke  -n mycc  -c '{"Args":["DataContract:CreateProduct", '\"$Product\"']}' -C myc 
elif [[ $mode == "updateprod" ]]; then
	peer chaincode invoke  -n mycc  -c '{"Args":["DataContract:UpdateProduct", '\"$Product\"']}' -C myc 
elif [[ $mode == "updatepol" ]]; then
	peer chaincode invoke  -n mycc  -c '{"Args":["DataContract:UpdatePolicy", '\"$Policy\"']}' -C myc 
fi