TF_VAR_pub_key 			:= $(shell cat _keys/vault-key.pub)
ANSIBLE_ROLES_PATH 	:= ./ansible/roles
ANSIBLE_CONFIG 			:= ./ansible/ansible.cfg

export ANSIBLE_CONFIG ANSIBLE_ROLES_PATH
export TF_VAR_aws_profile TF_VAR_pub_key
export TF_VAR_aws_prvnet TF_VAR_aws_subnet


# An implicit guard target, used by other targets to ensure
# that environment variables are set before beginning tasks
assert-%:
	@ if [ "${${*}}" = "" ] ; then 																						\
	    echo "Environment variable $* not set" ; 															\
	    exit 1 ; 																															\
	fi

vault:
	@ read -p "Enter AWS Profile Name: " profile ; 																																																							\
	prvnet=`aws --profile "$${profile}" --region us-west-2 ec2 describe-vpcs |jq -r '.[] | first | .VpcId'` ; 																									\
	subnet=`aws --profile "$${profile}" --region us-west-2 ec2 describe-subnets --filters "Name=vpc-id,Values=$${prvnet}" |jq -r '.[] | first | .SubnetId'` ; 	\
																																																																															\
	TF_VAR_aws_profile=$$profile TF_VAR_aws_prvnet=$$prvnet TF_VAR_aws_subnet=$$subnet make keypair && \
	TF_VAR_aws_profile=$$profile TF_VAR_aws_prvnet=$$prvnet TF_VAR_aws_subnet=$$subnet make build   && \
	TF_VAR_aws_profile=$$profile TF_VAR_aws_prvnet=$$prvnet TF_VAR_aws_subnet=$$subnet make plan    && \
	TF_VAR_aws_profile=$$profile TF_VAR_aws_prvnet=$$prvnet TF_VAR_aws_subnet=$$subnet make apply

build: require-packer
	aws-vault exec $(TF_VAR_aws_profile) --assume-role-ttl=60m -- \
	"/usr/local/bin/packer" "build" 															\
		"-var" "builder_subnet_id=$(TF_VAR_aws_subnet)" 						\
		"-var" "builder_vpc_id=$(TF_VAR_aws_prvnet)" 								\
	"packer/vault.json"

require-packer: assert-TF_VAR_aws_prvnet assert-TF_VAR_aws_subnet
	@ echo "[info] VPC:  $(TF_VAR_aws_prvnet)" ;
	@ echo "[info] NET:  $(TF_VAR_aws_subnet)" ;
	packer --version &> /dev/null


require-vault:
	aws-vault --version &> /dev/null

require-ansible:
	ansible --version &> /dev/null

require-tf: assert-TF_VAR_aws_profile require-vault
	@ echo "[info] Profile:  $(TF_VAR_aws_profile)"
	terraform --version &> /dev/null
	terraform init

require-jq:
	jq --version &> /dev/null



keypair:
	yes y |ssh-keygen -q -N ''  -f _keys/vault-key >/dev/null

ansible-roles:
	ansible-galaxy install -r ansible/requirements.yml


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
