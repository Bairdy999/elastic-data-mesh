#!/bin/bash

baseDir="/mnt/data/mesh"
elasticPassword=""
credsFile="$baseDir/credentials.txt"

if [ "$2" == "reset" ] || [ "$3" == "reset" ]; then
	echo "Removing all existing data for reset..."
fi
exit 0

if [ -f $credsFile ]; then
   echo "File $credsFile exists..."
else
	echo "Creds file does not exist"
fi
#exit

elasticPassword=$(grep elastic $credsFile | awk -F= '{print $2}')

echo "elastic password = $elasticPassword"
exit

cat $credsFile | while read line || [[ -n $line ]];
do
   [[ ${line//[[:space:]]/} =~ ^#.* || -z "$line" ]] && continue
   echo $line | tr "=" "\n" | while read -r key; do
   read -r value
   	 echo "key: ${key} and value: ${value}";
			if [[ "${key}" == "elastic" ]]; then
			echo $key
			echo $value
				export elasticPassword=$value
			fi
   done
done
echo "elastic password = ${elasticPassword}"
exit

declare -A v=( )
while read -r var value; do
  v[$var]=$value
  echo $var
done < "/mnt/data/mesh/credentials.txt"

while read -r var value; do
  printf -v "v_$var" %s "$value"
done < "/mnt/data/mesh/credentials.txt"