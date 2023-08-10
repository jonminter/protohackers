# protohackers

Solutions to protohackers problems

## Run locally

```
make prob_num=0 run
```

## Build debug

```
make prob_num=0 build-debug
```

## Setup AWS infrastructure

```
make tf-apply
```

## Build/deploy release

```
make prob_num=0 build
make prob_num=0 deploy
```

## SSH into instance

First, set up an AWS CLI profile that will assume the SSH role:

```
make setup-aws-profile
```

This is designed to work with IAM Identity Center SSO credentials. It will ask for the `Source Profile` that has permission to assume the SSH role.

Next, generate an SSH key

```
make gen-ssh-key
```

Now, we can use EC2 instance connect to send the SSH key and login:

```
make ssh-to-ec2
```
