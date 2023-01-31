#!/bin/bash

## Add Crontab Scheduler
# echo "*/1 * * * * root /bin/bash {INSTALL_PATH}/stat_banner/system_stat.sh"  > /etc/cron.d/system_stat_banner

# script description
_version='v0.0.3'
_creator="hnsong"
_create_date="2023.01.10"  # create or update

#script_path=$(echo $0 | xargs dirname)
script_path=$(cd $(echo "$0" | xargs dirname) ; echo $PWD ; (cd - > /dev/null))
PID="$$"

## Common ENV : Echo Color
c_red='\033[0;31m'              ## Red Color
c_green='\033[0;32m'            ## Green Color
c_orange='\033[0;33m'           ## Orange Color
c_blue='\033[0;34m'             ## Blue Color
c_yellow='\033[1;33m'           ## Yellow Color
c_bold_green='\033[1;32m'       ## Green Color
c_magenta='\033[1;95m'		## magent Color (same is purple)
c_light_red='\033[1;31m'
nc='\033[0m'                    ## Unset Color(NoColor)

AWS_INFO_FILE="${script_path}/aws_info.json"

run_stat=$(ps -elf | grep -E "$(basename $0)" | grep -Ev "\/bin\/sh -c|grep|${PID}|vi|cat" | grep -E "$(basename $0)" > /dev/null ; echo $?)
if [ ${run_stat} -eq 0 ] ; then
        exit 0
fi

#source /etc/bashrc
if [ $(cat /etc/*lease | grep ubuntu > /dev/null ; echo $?) -eq 0 ] ; then
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
        OS_VERSION=$(cat < /etc/lsb-release | grep "DISTRIB_DESCRIPTION" | awk -F '[=]' '{print $2}' | tr -d "\"")
        GET_OS_INSTALL_DATE=$(LANG=C && tune2fs -l $(df / | tail -1 | cut -f1 -d' ') | grep 'Filesystem created' | sed -e "s/Filesystem created: *//g")
else
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
	if [ -f "/etc/redhat-release" ] ; then
	        OS_VERSION=$(cat < /etc/redhat-release)
	else
	        OS_VERSION=$(cat < /etc/system-release)
	fi
        GET_OS_INSTALL_DATE=$(LANG=C && rpm -qi basesystem | grep "Install Date" | sed -e "s/^Install Date: *//g")
fi

if [ $(date -d "${GET_OS_INSTALL_DATE}" 2>1 > /dev/null ; echo $?) -eq 0 ]; then
	OS_INSTALL_DATE=$(date -d "${GET_OS_INSTALL_DATE}" "+%Y/%m/%d %H:%M:%S")
else
    	GET_OS_INSTALL_DATE=$(stat /root/anaconda-ks.cfg | grep "^Modify" | sed -e "s,.*\(20[0-9][0-9].*\) .*,\1,g")
    	OS_INSTALL_DATE=$(date -d "${GET_OS_INSTALL_DATE}" "+%Y/%m/%d %H:%M:%S")
fi

# Config file load
config_directory="${script_path}/include.d"
if [[ $(test -d ${config_directory}; echo $?) -eq 0 ]] ; then
	config_list=$(ls -al ${config_directory}/ | grep -E "\.cfg|\.sh" | awk '{print $(NF)}')
	for config_file in ${config_list} ; do
	        source "${config_directory}/${config_file}"
	done
fi

export PATH
export on_aws_instance=${on_aws_instance:-'None'}


AWS_INFO_FILE="${script_path}/aws_info.json"

ipCmd=$(/usr/bin/which ip | awk '{print $1}')
printfCmd='/usr/bin/printf'
KERNEL_VERSION=$(uname -r)
CPU_TIME=$(ps -eo pcpu | awk 'NR>1' | awk '{tot=tot+$1} END {print tot}')
CPU_CORES=$(cat < /proc/cpuinfo | grep -c processor)
CPU_USAGE=$(echo "scale=2;$CPU_TIME/$CPU_CORES" | bc -l)
CPU_LOAD_AVERAGE=$(uptime | awk '{print "1m(" $(NF-2) ") / 5m(" $(NF-1) ") / 15m (" $(NF) ")" }' | tr -d ",")

shap_print() {
:<<"END"
usage )
 shap_print "shap_print_cnt=10"
 shap_print "shap_print_cnt=10, is_end:true"
END
        shap_print_s_cnt=1
        for item in $(echo $* | tr "," " "); do
                item_key=$(echo ${item}| tr ":=" " " | awk '{print $1}')
                item_value=$(echo ${item}| tr ":=" " " | awk '{print $2}')
                case  ${item_key} in
                        "shap_print_cnt" )      shap_print_cnt="${item_value}"  ;;
                        "is_end" )              is_end="${item_value}"          ;;
                esac
        done

        if [ -z ${shap_print_cnt} ] ; then
                shap_print_cnt=100
        fi

        if [ -z "${is_end}" ] ; then
                is_end='false'
        fi

        if [ "${is_end}" == "true" ] ; then
                output_cmd="tee -a /etc/motd"
        else
                output_cmd="tee /etc/motd"
        fi

        while [ ${shap_print_s_cnt} -le ${shap_print_cnt} ] ; do
                if [ ${shap_print_s_cnt} -eq 1 ] ; then
                        ${printfCmd} "\n\n"
                fi
                ${printfCmd} "#"
                shap_print_s_cnt=$(( ${shap_print_s_cnt} + 1 ))
        done | ${output_cmd} >/dev/null

        if [ "${is_end}" == "true" ] ; then
                ${printfCmd} "\n\n\n" | ${output_cmd} >/dev/null
        fi
}

dash_print() {
	local loop_cnt=${1:-10}
	for (( i=1 ; i<=${loop_cnt}; i++)); do
		${printfCmd} "-"
	done
}

uptime_check() {
	BOOTING_DATE=$(date -d "$(uptime -s | awk '{print $1}')" '+%s')
	NOW_DATE=$(date '+%s')

	UPTIME_DAY=$(( $(( ${NOW_DATE} - ${BOOTING_DATE} )) / 86400 ))

	if [ ${UPTIME_DAY} -le 200 ]; then
		date_print_color="${c_green}"
	elif [ ${UPTIME_DAY} -gt 200 ] && [ ${UPTIME_DAY} -le 365 ] ; then
		date_print_color="${c_yellow}"
	else
		date_print_color="${c_red}"
	fi

	#${printfCmd} " - ${date_print_color}System Uptime             = %s${nc}\n"   "$(uptime | awk -F ',' '{print $1}' | sed -e 's/^ //g')"
	${printfCmd} " - ${date_print_color}System Uptime             = %s${nc}\n"   "${UPTIME_DAY} days"
}

ip_check() {
	exclude_grep_word='scope host lo|inet 132.0|187.0'
	if [ $(which dig > /dev/null ; echo $?) -eq 0 ] ; then
		if [ $(ping -c 1 cisco.com 2>/dev/null > /dev/null ; echo $?) -eq 0 ] ; then
			IP_TYPE="Public IP "
			Local_IPADDR=$(/usr/bin/dig +short myip.opendns.com @resolver1.opendns.com)

			GW_ADDR=$(${ipCmd} route | grep default | tr " "  "\n" | grep -E  -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
			grep_word="$(echo ${GW_ADDR} | awk -F '[.]' '{print $1 "." $2 "."}')"

			REAL_IP_IF_NAME=$(${ipCmd} -f inet -o addr | grep -Ev "${exclude_grep_word}" | grep -E "${grep_word}"| awk '{print $2}')
			REAL_IP=$(${ipCmd} -f inet -o addr | grep -Ev "${exclude_grep_word}" | grep -E "${grep_word}" | awk '{print $4}')

			if [ $(${ipCmd} -f inet -o addr | grep "${Local_IPADDR}" > /dev/null ; echo $?) -ne 0 ] ; then
				Local_IPADDR="${Local_IPADDR} (REAL_IP => ${REAL_IP_IF_NAME} : ${REAL_IP})"
			else
				Local_IPADDR="${Local_IPADDR}"
			fi
		else
	       		IP_TYPE="Local IP "
			GW_ADDR=$(${ipCmd} route | grep default | tr " "  "\n" | grep -E  -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
			REAL_IP_IF_NAME=$(${ipCmd} -f inet -o addr | grep -Ev "docker|\ lo|virbr" | head -1 |awk '{print $2}')
	       		Local_IPADDR=$(${ipCmd} -f inet -o addr | grep -Ev "${exclude_grep_word}" | grep -E "${REAL_IP_IF_NAME}" | awk '{print $2 " (" $4 ")" }')
		fi
	else
		IP_TYPE="Local IP "
		Local_IPADDR=$(${ipCmd} -f inet -o addr | grep -Ev "${exclude_grep_word}" | awk '{print $2 " (" $4 ")" }')
		REAL_IP_IF_NAME=$(${ipCmd} -f inet -o addr | grep -Ev "${exclude_grep_word}" |grep -E "${grep_word}"| awk '{print $2}')
	fi
}

aws_get_info() {

        account_name="None"
        region_name="None"
        return_value=""

        for item in $(echo $* | tr "," " "); do
                item_key=$(echo ${item} | tr ":=" " " | awk '{print $1}')
                item_value=$(echo ${item} | tr ":=" " " | awk '{print $2}')
                case  ${item_key} in
                        account_id )
                                account_id="${item_value}"
                                if [ -f ${AWS_INFO_FILE} ] ; then
                                        account_name=$(eval "cat < ${AWS_INFO_FILE} | jq -r '.aws.account.\"${account_id}\"'")
                                fi

                                if [ ${account_name} == 'None' ] || [ $(echo ${account_name} | tr "[:upper:]" "[:lower:]") == 'null' ] ; then
                                        #account_name="Not found Account ID"
                                        account_name="Account ID"
                                fi

                                return_value="${account_name}"
                                ;;
                        region_id )
                                region_id="${item_value}"
                                if [ -f ${AWS_INFO_FILE} ] ; then
                                        region_name=$(eval "cat < ${AWS_INFO_FILE} | jq -r '.aws.region.\"${region_id}\"'")
                                fi
                                if [ ${region_name} == 'None' ] || [ $(echo ${region_name} | tr "[:upper:]" "[:lower:]") == 'null' ] ; then
                                        #region_name="Not found Region ID"
                                        region_name="Region ID"
                                fi

                                return_value="${region_name}"
                                ;;
                esac
        done

        echo "${return_value}"
}

aws_machine_info() {
        CURL_CMD="curl -s --connect-timeout 5"
        AWS_INFO_IP_ADDRESS="169.254.169.254"
        AWS_INFO_URL="http://${AWS_INFO_IP_ADDRESS}/latest/meta-data"
        run_stat=$(curl -s ${AWS_INFO_IP_ADDRESS} --connect-timeout 3 > /dev/null ; echo $?)
        if [ ${run_stat} -eq 0 ] ; then
                curl_stat=$(${CURL_CMD} -o /dev/null -w "%{http_code}" ${AWS_INFO_URL}/identity-credentials/ec2/info)
                if [ ${curl_stat} -eq 200 ] ; then
                        account_id=$(${CURL_CMD} ${AWS_INFO_URL}/identity-credentials/ec2/info | grep -i "account" | awk '{print $(NF)}' | sed -e "s/\"//g")
                        ${printfCmd} " - ${c_yellow}%-25s = %-s${nc}\n" "AWS Account" "$(aws_get_info account_id=${account_id}) (${account_id})"

                        region_id=$(${CURL_CMD} ${AWS_INFO_URL}/placement/region)
                        ${printfCmd} " - ${c_magenta}%-25s = %-s${nc}\n" "AWS Region" "$(aws_get_info "region_id=${region_id}") (${region_id})"

                        az_name=$(${CURL_CMD} ${AWS_INFO_URL}/placement/availability-zone)
                        ${printfCmd} " - ${c_orange}%-25s = %-s${nc}\n" "AWS Availability Zone" "${az_name}"

                        # Instance ID
                        ${printfCmd} " - ${c_yellow}%-25s = %-s${nc}\n" "Instance ID" "$(curl -s ${AWS_INFO_URL}/instance-id ; echo "")"

                        # Instance Type
                	${printfCmd} " - ${c_yellow}%-25s = %-s${nc}\n" "InstanceType" "$(curl -s ${AWS_INFO_URL}/instance-type ; echo "")"
                fi  | tee -a /etc/motd > /dev/null
        else
		if [ ! -d "${config_directory}" ] ; then
			mkdir -p "${config_directory}"
		fi

		if [ -f "${config_directory}/config.cfg" ]; then
			sed -i "/^on_aws_instance.*$/d" ${config_directory}/config.cfg
			get_linenum=$(grep -n "^on_aws_instance" ${config_directory}/config.cfg | awk -F ':' '{print $1}')
			sed -i "${get_linenum:-2} i\on_aws_instance='false'" ${config_directory}/config.cfg
		else
			echo "on_aws_instance='false'" | tee -a ${config_directory}/config.cfg > /dev/null
		fi
        fi
}

aws_machin_check() {
    if [ "${on_aws_instance:-'None'}" == "None" ] || [ "${on_aws_instance:-'None'}" == "true" ]; then
        aws_machine_info;
    fi
}



nic_check() {
	eth_if_len=0
    	ip_addr_len=0
    	for_idx=0
	etc_interface_cnt=$(${ipCmd} -f inet -o addr | grep -Ev "scope host lo|inet 132.0|187.0|${REAL_IP_IF_NAME}" | awk '{print $2}' | wc -l)

	if [ ${etc_interface_cnt} -ne 0 ] ; then

		etc_address=$(${ipCmd} -f inet -o addr | grep -Ev "scope host lo|inet 132.0|187.0|${REAL_IP_IF_NAME}" | awk '{print $2}' | sort -r)
		for etc_if in ${etc_address} ; do
			ipaddress=$(${ipCmd} -f inet -o addr show ${etc_if} | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}/[0-3][0-9]")
			eth_len=$(echo ${etc_if} | wc -c)
			ip_len=$(echo ${ipaddress} | wc -c)
			if [ $((${eth_len})) -ge ${eth_if_len} ]; then
				eth_if_len=$(echo ${etc_if} | wc -c)
			fi

			if [ $((${ip_len})) -ge ${ip_addr_len} ]; then
			    	ip_addr_len=$(echo ${ipaddress} | wc -c)
			fi

			eth_if_array[${for_idx}]=${etc_if}
			ip_addr_array[${for_idx}]=${ipaddress}
			for_idx=$(( ${for_idx} + 1 ))
		done

		if [ ${eth_if_len} -le 15 ] ; then
			eth_if_len=15
		fi
		#### Docker IP address check
		if [ $(echo "Interface Name" | wc -c) -ge ${eth_if_len} ] ; then
                        eth_if_len=$(echo "Interface Name" | wc -c)
                fi
		dash_cnt=$(( 7 + ${eth_if_len} + ${ip_addr_len} ))
		${printfCmd} " - ETC Interface Address \n"
		${printfCmd} "\t$(dash_print ${dash_cnt})\n"
		${printfCmd} "\t| %-${eth_if_len}s | %-${ip_addr_len}s |\n" "Interface Name" "IP Address"
		${printfCmd} "\t$(dash_print ${dash_cnt})\n"

		for (( i=0; i<${for_idx}; i++ )); do
		    	${printfCmd} "\t| %-${eth_if_len}s | %-${ip_addr_len}s |\n" "${eth_if_array[${i}]}" "${ip_addr_array[${i}]}"
		done
		${printfCmd} "\t$(dash_print ${dash_cnt})\n"
	fi |tee -a /etc/motd > /dev/null
}


network_drive_usage_check() {
	nfs_ip_list=$(mount -l | grep -E "nfs" | grep -Ev "tmpfs|sunrpc|fs\/nfsd|nfs/rpc_pipefs" | awk -F'[:]' '{print $1}' | sort -u)

	if [ -n "${nfs_ip_list}" ]; then
		${printfCmd}  "\t-------  NFS Mount List & Partition's -------\n"  |tee -a /etc/motd > /dev/null
		for nfsIpList in ${nfs_ip_list} ; do
			nfs_localpath=$(mount -l | grep "${nfsIpList}" | awk '{print $3}')
			for nfslist in ${nfs_localpath} ; do
				partition_name="${nfslist}"
				pSize=$(df ${partition_name} -h | awk '{ a = $4 } END { print a }')
				if [ -z "${pSize}" ] ; then
					pSize=$(df ${partition_name} -h | awk '{ a = $3 } END { print a }')
				fi

	                	used_percent=$(df ${partition_name} -h | awk '{ a = $5 } END { print a }')
				if [ -z "${used_percent}" ] ; then
					used_percent=$(df ${partition_name} -h | awk '{ a = $4 } END { print a }')
				fi

				${printfCmd}  "\t%-40s\t: %6s (%s)\n"  "${partition_name}" "${pSize}" "${used_percent}" |tee -a /etc/motd > /dev/null
			done
		done
	fi
}

disk_usage_check() {
	## disk Usage check
	${printfCmd} " - Disk Space Used\n" | tee -a /etc/motd > /dev/null

	partition_list=$(mount -l  | grep -E "xfs|ext" | grep -Ev "tmpfs|sunrpc|fs\/nfsd|selinuxfs" | awk '{print $1}')
	for pList in ${partition_list} ; do
		partition_name=$(df -h | grep "${pList} " | awk '{print $(NF)}')

		if [[ $(echo ${OS_VERSION} | grep -Ei "ubuntu|debian" > /dev/null ; echo $?) -eq 0 ]] ; then
			partition_name=$(mount -l | grep -E "${pList} " | awk '{print $3}')
		else
			partition_name=$(df -h | grep "${pList} " | awk '{print $(NF)}')
		fi

		if [ $(mount -l  | grep "${pList}" | grep nfs >/dev/null ; echo $?) -ne 0 ] ; then
			pSize=$(df ${partition_name} -h | awk '{ a = $4 } END { print a }')
			UsedSize=$(df ${partition_name} -h | awk '{ a = $3 } END { print a }')
			used_percent=$(df ${partition_name} -h | awk '{ print $5 }' | grep -E -o "(.[0-9])%|([0-9])%" | tr -d "%")
		else
			pSize=$(df ${partition_name} -h | awk '{ a = $3 } END { print a }')
			UsedSize=$(df ${partition_name} -h | awk '{ a = $3 } END { print a }')
			used_percent=$(df ${partition_name} -h | awk '{print $4 }'| grep -E -o "(.[0-9])%" | tr -d "%")
		fi

		if [ "${used_percent}" -gt 50 ]; then
			# print_color='\033[0;31m'
			print_color="${c_red}"
		else
			# print_color='\033[0;32m'
			print_color="${c_green}"
		fi

		${printfCmd}  "${print_color}\t%-40s\t: %-12s %-15s${nc}\n"  "${partition_name}" "Avail(${pSize})," "Used(${UsedSize} / ${used_percent}%)"
	done | tee -a /etc/motd > /dev/null

	network_drive_usage_check;
}

security_banner() {
	## Sevurity Banner
	system_banner_file="${script_path}/security_banner.cfg"
	if [ -f ${system_banner_file} ] ; then
		source ${system_banner_file}
		${printfCmd} "\n\n" >> /etc/motd
		system_banner | tee -a /etc/motd > /dev/null
	fi
}

main() {
	ip_check;
	mem_total=$(cat < /proc/meminfo  | grep "MemTotal" | awk '{print $2 / 1024}')
	mem_free=$(free -m | head -n 2 | tail -n 1 | awk '{print $4}')
	mem_cache=$(free -m | grep "Mem" | awk '{print $6}')

	shap_print "shap_print_cnt=100"
	{
		${printfCmd} "\n\n%s\n"					"System Summary (collected $(date))"
		${printfCmd} " - %-25s = ${c_bold_green}%-s${nc}\n" 	"Hostname"  "$(uname -n)"
		${printfCmd} " - %-25s = ${c_green}%-s${nc}\n" 		"${IP_TYPE}" "${Local_IPADDR}"
    		${printfCmd} " - %-25s = %s(%s)\n" 			"OS Version (Kernel)" "${OS_VERSION}" "${KERNEL_VERSION}"
		${printfCmd} " - %-25s = %s \n" 			"OS Install DATE" "${OS_INSTALL_DATE##+()}"
		${printfCmd} " - %-25s = %0.2f %%\n" 			"CPU Usage (average)" "${CPU_USAGE}"
		${printfCmd} " - %-25s = %-s \n" 			"CPU load average" "${CPU_LOAD_AVERAGE}"
		${printfCmd} " - %-25s = %-s \n" 			"Memory" "Total(${mem_total} Mb) / Free(${mem_free} Mb) / Cache(${mem_cache} Mb)"
		${printfCmd} " - %-25s = %-s \n" 			"Memory used" "$(free -m  | grep -E "Mem" | awk '{print $3}') Mb"
		${printfCmd} " - %-25s = %'.f Mb \n" 			"Swap in used" "$(free -m | tail -n 1 | awk '{print $3}')"
		uptime_check;
	} | tee -a /etc/motd > /dev/null
	aws_machin_check;
	nic_check;
	disk_usage_check;
	${printfCmd} "\n\n" >> /etc/motd
	security_banner;
	shap_print "shap_print_cnt=100" "is_end=true"

	cat < /etc/motd
}

main $*



##printf "\n\n
##          *******************************************************************************
##          *                      ☞  주 의 사 항  ☜                                      *
##          *                                                                             *
##          *     1. 지금 접속한 것이 정식 절차에 의해 본인이 부여 받은 계정입니까?       *
##          *     2. 주기적으로 패스워드를 변경하고 있습니까?                             *
##          *                                                                             *
##          *     허가 받은 사용자가 아니면 당신은 즉시 나가세요!!!                       *
##          *                                                                             *
##          *          주 의 : 모든 사항은 모니터링되고 있습니다.                         *
##          *                                                                             *
##          *                     ☞  시스템 관리자  ☜                                     *
##          *                                                                             *
##          *******************************************************************************
##\n\n" | tee -a /etc/motd
