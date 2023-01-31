#!/usr/bin/env bash 

script_path=$(cd $(echo "$0" | xargs dirname) ; echo $PWD ; (cd - > /dev/null))
if [ $(cat /etc/*lease | grep -i "ubuntu" > /dev/null ; echo $? ) -eq 0 ] ; then
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
else
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
fi

os_check() {
    if [ -f /etc/redhat-release ]; then
        echo "centos"
    fi

    if [ -f /etc/lsb-release ]; then
        echo "ubuntu"
    fi

    if [ `grep 'NAME=\"Amazon Linux\"' /etc/os-release | wc -l`  = 1 ]; then
        echo "amazon"
    fi
}

print_console() {
	echo " ++ [$(date +'%Y-%m-%d %H:%M:%S.%3N')] $*"
}

print_run() {
	eval "$*"
	RETURN_VAL=$?
	print_console "CMD[${RETURN_VAL}]) $*"
}

create_dir() {
        if [ ! -d "$1" ] ; then
                print_run "mkdir -p $1"
        fi
}


#source /etc/bashrc
if [ $(cat /etc/*lease | grep ubuntu > /dev/null ; echo $?) -eq 0 ] ; then
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
        OS_VERSION=$(cat < /etc/lsb-release | grep "DISTRIB_DESCRIPTION" | awk -F '[=]' '{print $2}' | tr -d "\"")
else
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
        if [ -f "/etc/redhat-release" ] ; then
                OS_VERSION=$(cat < /etc/redhat-release)
        else
                OS_VERSION=$(cat < /etc/system-release)
        fi
fi

export PATH


if [ -z "${os_user}" ]; then 
	echo "${OS_VERSION}" | grep -Ei "ubuntu" > /dev/null 
	ret_code=$?
	if [ ${ret_code} -eq 0 ] ; then
		os_user="ubuntu"	
	fi
fi
	
dest_path="/root/.system_check"
source_path="${script_path}"

print_console "echo : \$os_user = ${os_user}"
print_console "echo : \$pwd = $(pwd)"


if [ -d "${source_path}" ] ; then 
	print_run "sudo mkdir -p ${dest_path}"
	print_run "sudo cp -rpRf ${source_path}/../system_stat.sh ${dest_path}/"
	print_run "sudo cp -rpRf ${source_path}/../*_banner.cfg ${dest_path}/"

	sudo ls -al ${dest_path}/ | grep -Ei "system_stat.sh" > /dev/null
	if [ $? -eq 0 ] ; then 
		sudo cat /etc/crontab | grep "system_stat.sh" > /dev/null 
		if [ $? -ne 0 ] ; then 
			print_console "Add /etc/crontab "
			echo "# Add To System Check Script $(date +'%Y-%m-%d')" | sudo tee -a /etc/crontab
			echo "*/1 * * * * root /bin/bash ${dest_path}/system_stat.sh" | sudo tee -a /etc/crontab
			cat < /etc/crontab | grep -B3 -A2 "system_stat.sh"
		fi
		
		print_run "sudo chmod +x ${dest_path}/system_stat.sh"
		print_run "sudo ls -al ${dest_path}"
		#print_run "rm -rf ${source_path}"
	else
		print_console "Not Found File : ${dest_path}/system_stat.sh"
	fi
else
	print_console "Not Found Directory : \${source_path} => ${source_path}"
fi

