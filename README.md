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

First, generate an SSH key

```
make gen-ssh-key
```

Now, we can use EC2 instance connect to send the SSH key and login:

```
make ssh-to-ec2
```
