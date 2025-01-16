# Out of Box kubernetes

This is an assignment activity

## Tools needed

* terraform (virtual machine creation and boot up)
* QEMU/libvirt
* cdrtools (mkisofs used by terraform)
* dnsmasq (used by terraform)
* libxslt (used by terraform)
* ansible (configuration and install of DevOps tools)
* docker
* kubernetes
* ssh
* nix (optional)
* direnv (optional)

### More info

With nix-shell, you can easily setup your environment tools and directories needed (more on that later), as in with direnv you can automagically enter nix-shell when inside the project directory tree.

All the commands assume that you are at the root directory of this project.

## Terraform

First off, you need to initialize the terraform settings (notice that this is already done by nix-shell if you are using it):

    terraform init

Also make sure that you have the following directory (also done by nix-shell):

    mkdir -p pool/images/terraform-provider-libvirt-pool-ubuntu

Create an ssh-key on the keys directory by executing (only if the 'keys/' directory is empty):

    ssh-keygen -t id_25519 -f keys/id_ed25519

Notice that if you are using nix-shell, on its first execution it should automate the key creation command, asking only for the password.

Afterwards you can create and start the VM by executing:

    terraform apply

If desired, you can access the newly created VM by executing:

    ssh -i keys/id_25519 userA@10.10.10.100

Notice that if you changed the terraform script, you have to also change the credentials and ip address if needed.

## Ansible

To be able to run this playbook you need to have the community.kubernetes and community.docker collections, install them:

    ansible-galaxy collection install community.kubernetes

    ansible-galaxy collection install community.docker

Also, be sure that you have the necessary python packages:

    pip install kubernetes docker

If using the nix-shell these two from above are already covered.

Now, you can run the ansible script that installs the tools used by this project onto the targeted VM:

    ansible-playbook -i inventory.ini playbook.yaml

Note, the inventory.ini file contains the user (userA), IP address (10.10.10.100) and ssh keys used on this project, if you changed the terraform script be sure to also update it accordingly.

After it, if desired, we can execute the kubernetes part:

    ansible-playbook -i inventory.ini deploy-nginx.yaml

With this, the nginx server should be accessible on your browser (by default on 10.10.10.100:30080)

## Kubernetes

If you are following the guide, the kubernetes tools setup was already done by ansible.

ssh'd your guest machine and start the minikube to a simple local kubernetes setup

    minikube start

Load the minikube's docker environment into your shell so minikube can work properly

    eval $(minikube docker-env)

As we are inside the docker env provided by minikube we need to rebuild the docker image, go to `/opt/nginx-k8s` (hello world project provided for the execution of this assignment) and build it:

    cd /opt/nginx-k8s
    docker build -t nginx-custom:latest .

Still on the current directory, proceed to execute both the deployment and service of this cluster:

    kubectl apply -f deployment.yaml

    kubectl apply -f service.yaml

With this done, this kubernetes hello-world web application is finally available at port 8080 of your host machine (port forwarding by terraform script).

You can also see the deployment, services and pods being currently executed by running:

    kubectl get deployments

    kubectl get services

    kubectl get pods
