#!/bin/bash
CONTROLLER_IP=172.16.53.68 #Controller's IP 
USER_NAME=root
SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
#SSH_CMD="ssh ${SSH_OPTS} -i id_rsa.${USER_NAME} ${USER_NAME}@${FUEL_IP}"
#SSH_CMD="sshpass -p r00tme ssh ${SSH_OPTS} ${USER_NAME}@${FUEL_IP}"
SSH_CMD="ssh root@${CONTROLLER_IP}"
#SCP_CMD="sshpass -p r00tme scp ${SSH_OPTS} root@${FUEL_IP}"
SCP_CMD="scp root@${CONTROLLER_IP}" 

# Will be used for test_results publishing
TIME="MSK-$(date +%Y-%m-%d-%H:%M:%S)"

echo $TIME

${SSH_CMD} ls -la

echo -n "Begin Shaker test(s) at "
date

#${SCP_CMD}:/root/.ssh/id_rsa id_rsa.${USER_NAME}
REPORTS_DIR=`${SSH_CMD} "mktemp -d"`

echo "Created reports dir name: " $REPORTS_DIR

# Create script on remote node to run  
REMOTE_SCRIPT=`${SSH_CMD} "mktemp"`

echo "!!! -2- Running SSH_CMD"
${SSH_CMD} "cat > ${REMOTE_SCRIPT}" <<EOF
#!/bin/bash -xe

#SHAKER_PATH=${SHAKER_PATH}
TEST_SUBJECT=${TEST_SUBJECT:-networking}
REPORTS_DIR=`mktemp -d`
SERVER_ENDPOINT=172.16.53.68
#SERVER_ENDPOINT=ifconfig\|grep\ br-ex\ -A\ 3\|grep\ inet\ addr\|awk\ '{print \$2}'\|sed\ 's/addr://g 
SERVER_PORT=18000

echo \$SERVER_ENDPOINT

#install shaker
apt-get -y install python-dev libzmq-dev python-pip && pip install pbr pyshaker


# Prepare environment
##test -f /home/developer/openrc        && source /home/developer/openrc
##test -f /opt/stack/.venv/bin/activate && source /opt/stack/.venv/bin/activate
source /root/openrc

# Disable neutron quotas  # j: ????
##for res in floatingip  network port router security_group  security_group_rule subnet ; do
  ##neutron quota-update --\${res} -1
  ##done
  
  # Disable nova quotas
  ##OS_TENANT_ID=\$(keystone tenant-get \${OS_TENANT_NAME} | awk '\$2 == "id" {print \$4}')
  ##for res in ram cores instances; do
  ##  nova quota-update --\${res} -1 \${OS_TENANT_ID}
  ##done
  
  #cd \${SHAKER_PATH}
  
  # Prepare Shaker OS image if it doesn't exists
  if ! glance image-show shaker-image
  then
##if [ -x /opt/stack/.venv/bin/shaker-image-builder ]
 ##then
 ##/opt/stack/.venv/bin/shaker-image-builder
 shaker-image-builder --debug
##else
##\${SHAKER_PATH}/bin/prepare.sh
 #fi
  fi
                      
 iptables -I INPUT -s 10.20.0.0/16 -j ACCEPT
 iptables -I INPUT -s 10.0.0.0/16 -j ACCEPT
 iptables -I INPUT -s 172.16.0.0/16 -j ACCEPT 
 iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT
                      
 # Run Shaker
 ##for scenario_file in /opt/stack/shaker-scenarios/\${TEST_SUBJECT}/${TEST_GLOB:-*.yaml}
 for scenario_file in /usr/local/lib/python2.7/dist-packages/shaker/scenarios/\${TEST_SUBJECT}/${TEST_GLOB:-*.yaml}
 do
 echo $scenario_file
 scenario_name=\${scenario_file##*/}
 scenario_name=\${scenario_name%.*}
 echo \$scenario_name
 
# shaker --server-endpoint 172.16.53.68:18000 --scenario networking/iperf_instances_same_node --report perf_instances_same_node_VLAN.html --debug
 
 echo -n "Run Shaker scenario \${scenario_name} at "
 date
 time shaker --debug \
    --server-endpoint \$SERVER_ENDPOINT:\$SERVER_PORT \
    --scenario networking/\${scenario_name} \
    --report ${REPORTS_DIR}/\${scenario_name}.html \
    --output ${REPORTS_DIR}/\${scenario_name}.json \
    --subunit ${REPORTS_DIR}/\${scenario_name}.subunit \
    --log-file ${REPORTS_DIR}/\${scenario_name}.log
done
cd -
                                                            
                                                            
#Script finish
EOF

                        
#Run script on remote node and get exit code
${SSH_CMD} "bash -xe ${REMOTE_SCRIPT}"
                        
# Delete script on remote node
#${SSH_CMD} "rm -f ${REMOTE_SCRIPT}"
                                                            
                                                            #########
                                                            ###Part#2
                                                            #########
                                                            
echo "Node list:"
# Generate node list
NODELIST=${REPORTS_DIR}/_nodelist.html
echo "NODELIST .html file: " $NODELIST
${SSH_CMD} "cat > ${NODELIST}" <<EOF
<html>
    <head>
         <title>Cluster node list</title>
              <style type="text/css">
        table {border-collapse: collapse; width: 100%; font-family: monospace;}
        table, th {border: 2px solid black;}
        td {border: 1px solid black;}
         </style>
         </head>
             <body>
              <table>
        <tr><th>Hostname</th><th>Name</th><th>IP address</th><th>MAC address</th><th>Roles</th></tr>
EOF

echo "END OF Node list:"                                                                        
                                                                
${SSH_CMD} "fuel nodes | awk -F\\| 'function trim(string) {return gensub(/(^ +)|( +)\$/, \"\", \"g\", string)} trim(\$2) == \"ready\" {printf(\"  <tr><td>node-%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\\n\", trim(\$1), trim(\$3), trim(\$5), trim(\$6), trim(\$7))}' >> ${NODELIST}"
                                                    
${SSH_CMD} "cat >> ${NODELIST}" <<EOF
 </table>
 </body>
 </html>
 EOF
 
                                                                 
# Jenkins not clears workdir between runs
##rm -f *.html *.log
# Copy reports and remove temporary directory
 ${SCP_CMD}:${REPORTS_DIR}/* .
                                     
# ${SSH_CMD} "rm -rf ${REPORTS_DIR}"
                                                                     
echo -n "End Shaker test(s) at "
date
                                                                         
                                                                         