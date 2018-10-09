TF_VAR_pub_key 			:= $(shell cat _keys/ec2-key.pub)
ANSIBLE_ROLES_PATH 	:= ./ansible/roles
ANSIBLE_CONFIG 			:= ./ansible/ansible.cfg

export ANSIBLE_CONFIG ANSIBLE_ROLES_PATH
export TF_VAR_aws_profile


# An implicit guard target, used by other targets to ensure
# that environment variables are set before beginning tasks
assert-%:
	@ if [ "${${*}}" = "" ] ; then 																						\
	    echo "Environment variable $* not set" ; 															\
	    exit 1 ; 																															\
	fi

vpn:
	@ read -p "Enter AWS Profile Name: " profile  ; 													\
																																						\
	TF_VAR_aws_profile=$$profile make keypair 	&& 														\
	TF_VAR_aws_profile=$$profile make apply 		&& 														\
	TF_VAR_aws_profile=$$profile make reprovision


require-vault:
	aws-vault --version &> /dev/null

require-ansible:
	ansible --version &> /dev/null

require-tf: assert-TF_VAR_aws_profile require-vault
	@ echo "[info] Profile:  $(TF_VAR_aws_profile)"
	terraform --version &> /dev/null
	terraform init

require-packer: require-packer
	@ echo "[info] Profile:  $(TF_VAR_aws_profile)"
	packer --version &> /dev/null

require-jq:
	jq --version &> /dev/null



keypair:
	yes y |ssh-keygen -q -N ''  -f _keys/ec2-key >/dev/null

ansible-roles:
	ansible-galaxy install -r ansible/requirements.yml

# aws --profile GEHC-030 --region us-west-2 ec2 describe-vpcs |jq -r '.[] | first | .VpcId' ##First VPC Id
# aws --profile GEHC-030 --region us-west-2 ec2 describe-subnets --filters 'Name=vpc-id,Values=^whatevers up there' |jq -r '.[] | first | .SubnetId'
build: require-packer
	aws-vault exec $(TF_VAR_aws_profile) --assume-role-ttl=60m -- "/usr/local/bin/packer" "build" "packer/vault.json"


plan: require-tf
	aws-vault exec $(TF_VAR_aws_profile) --assume-role-ttl=60m -- "/usr/local/bin/terraform" "plan"

apply: require-tf require-ansible ansible-roles
	@ if [ -z "$TF_VAR_pub_key" ] ; then 																\
		echo "\$TF_VAR_pub_key is empty; run 'make keypair' first!"	; 		\
		exit 1 ; 																													\
	fi
	aws-vault exec $(TF_VAR_aws_profile) --assume-role-ttl=60m -- "/usr/local/bin/terraform" "apply" "-auto-approve"


plan-destroy: require-tf
	aws-vault exec $(TF_VAR_aws_profile) --assume-role-ttl=60m -- "/usr/local/bin/terraform" "plan" "-destroy"

destroy: require-tf
	aws-vault exec $(TF_VAR_aws_profile) --assume-role-ttl=60m -- "/usr/local/bin/terraform" "destroy" "-auto-approve"

clean: destroy
	rm -rf _keys/*.ovpn _keys/ec2-key* .terraform terraform.*


reprovision: require-tf require-jq
	ansible-playbook 																										\
	 -i `terraform output -json |jq -r '. |map(.value) |join (",")'`, 	\
	 -v	ansible/openvpn.yml |tee _logs/reprovision.log



debug-reprovision: require-tf require-jq
	echo >| _logs/debug-reprovision ;
	ANSIBLE_DEBUG=1 ansible-playbook 																		\
	 -i `terraform output -json |jq -r '.[].value' |tail -n1`, 					\
	 -vvvvv	ansible/openvpn.yml |tee _logs/debug-reprovision.log


ssh: require-tf
	@ read -p "Enter AWS Region Name: " region  ; 											\
	ssh 																																\
	 -i _keys/ec2-key 																									\
	 -l ubuntu 																													\
	 `terraform output -json |jq -r --arg region "$$region" ".[$$region].value"`
