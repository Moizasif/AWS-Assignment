# Minimal Node.js Hello World example

This repo contains a minimal hello world application written in Node. This repo will document the many ways you can deploy this application.

## Run locally

```bash
npm install
npm start
```

## Run in a container

```bash
docker build -t node-hello-world:latest .
docker run -it -p 5000:5000 --name node-hello-world node-hello-world:latest
````

## Terraform Code

main.tf contains all the the infrastructure related settings like Providers, VPC, Subnets, Route Tables.

alb.tf contains all the Load Balancer Configurations.

ecr.tf contains ecs cluster configurations like task service as well as ASG and iam roles and instance roles in order to run our application
