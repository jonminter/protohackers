setup:
	cargo install cross
gen-ssh-keys:
	mkdir -p .ssh_keys
	ssh-keygen -t rsa -b 4096 -f .ssh_keys/protohackers_key
	chmod 0400 .ssh_keys/protohackers_key
	chmod 0400 .ssh_keys/protohackers_key.pub
destroy-ssh-keys:
	rm -rf .ssh_keys

ssh-to-ec2:
	echo $$(./infra/scripts/instance.sh ip)
	AWS_REGION=us-east-1 AWS_PROFILE=protohackers_ssh aws ec2-instance-connect send-ssh-public-key --instance-id=$$(./infra/scripts/instance.sh id) --ssh-public-key file://.ssh_keys/protohackers_key.pub --instance-os-user ec2-user
	AWS_REGION=us-east-1 AWS_PROFILE=protohackers_ssh aws ec2-instance-connect ssh --instance-id $$(./infra/scripts/instance.sh id) --private-key-file .ssh_keys/protohackers_key

run-docker:
	export AWS_PROFILE=jonminter-infra
	docker build -t protohackers-solutions .
	docker run -it --rm -v ~/.aws:/home/ec2-user/.aws -v $(PWD):/app protohackers-solutions /bin/bash

INFRA_DIR=infra
tf-plan:
	cd $(INFRA_DIR) && ./create_tfvars.sh
	cd $(INFRA_DIR) && terraform plan -var-file=vars.tfvars
tf-apply:
	cd $(INFRA_DIR) && ./create_tfvars.sh
	cd $(INFRA_DIR) && terraform apply -var-file=vars.tfvars

install-colima:
	# download binary
	curl -LO https://github.com/abiosoft/colima/releases/download/v0.5.3/colima-$$(uname)-$$(uname -m)

	# install in $PATH
	sudo install colima-$$(uname)-$$(uname -m) /usr/local/bin/colima # or sudo install if /usr/local/bin requires root.

instance-id:
	cd $(INFRA_DIR) && terraform output instance_id
instance-ip:
	cd $(INFRA_DIR) && terraform output instance_ip

setup-aws-profile:
	./infra/scripts/setup_aws_profile.sh

PROBLEM_DIR=problem$(prob_num)_smoketest
test:
	cd $(PROBLEM_DIR) && cargo test
fmt:
	cd $(PROBLEM_DIR) && cargo fmt
lint:
	cd $(PROBLEM_DIR) && cargo check
	cd $(PROBLEM_DIR) && cargo clippy
run:
	cd $(PROBLEM_DIR) && cargo run
build:
	cd $(PROBLEM_DIR) && cargo build --release
build-debug:
	cd $(PROBLEM_DIR) && cargo build
build-arm:
	cd $(PROBLEM_DIR) && cross build --release --target aarch64-unknown-linux-gnu
deploy:
	cd $(PROBLEM_DIR) && aws s3 cp target/release/problem0_smoketest s3://protohacker-solutions/problem0_smoketest

telnet:
	telnet $(shell ./infra/scripts/instance.sh ip) 10000

submit:
	open https://protohackers.com/problem/$(prob_num)