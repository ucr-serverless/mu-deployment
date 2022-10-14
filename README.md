## Starting up a 11-node cluster on Cloudlab
1. When starting a new experiment on Cloudlab, select the **small-lan** profile
2. In the profile parameterization page, 
        - Set **Number of Nodes** as **11**
        - Set OS image as **Ubuntu 18.04**
        - Set physical node type as **c220g2**
        - Please check **Temp Filesystem Max Space**
        - Keep **Temporary Filesystem Mount Point** as default (**/mydata**)
3. We use `node-0` as master node. `node-1` to `node-10` are used as worker node.

## Extend the disk
On the master node and worker nodes, run
```bash
sudo chown -R $(id -u):$(id -g) <mount point(to be used as extra storage)>
cd <mount point>
git clone https://github.com/ucr-serverless/mu-deployment.git
cd <mount point>/mu-deployment
```
Then run `export MYMOUNT=<mount point>` with the added storage mount point name

- if your **Temporary Filesystem Mount Point** is as default (**/mydata**), please run
```
sudo chown -R $(id -u):$(id -g) /mydata
cd /mydata
git clone https://github.com/ucr-serverless/mu-deployment.git
cd /mydata/mu-deployment
git checkout autoscaler
export MYMOUNT=/mydata
```

## Deploy Kubernetes Cluster
1. Run `./100-docker_install.sh` without *sudo* on both *master* node and *worker* node
2. Run `source ~/.bashrc`
3. On *master* node, run `./200-k8s_install.sh master <master node IP address>`
4. On *worker* node, run `./200-k8s_install.sh slave` and then use the `kubeadm join ...` command obtained at the end of the previous step run in the master node to join the k8s cluster. Run the `kubeadm join` command with *sudo*
5. run `echo 'source <(kubectl completion bash)' >>~/.bashrc && source ~/.bashrc`

## Download Mu's repos (Make sure using the correct branch for every component)
```
./300-git_clone.sh
```

## Deploy Istio (quick setup)
1. If the system login name is different from the docker name then, run `export DOCKER_USER=<docker name>`
2. On master node, run `./400-prerequisite.sh`
3. On master node, run `sudo docker login` to login with your dockerhub account
4. On master node, run `sudo docker pull shixiongqi/istioctl:latest`
5. On master node, run `sudo docker create --name tmp_istioctl shixiongqi/istioctl:latest`
6. On master node, run `sudo docker cp tmp_istioctl:/usr/local/bin/istioctl ./`, then run `sudo docker rm -f tmp_istioctl`
7. On master node, run `./istioctl manifest install -f istio-de.yaml` to setup custom istio
**NOTE: we use the built-up image in shixiongqi's docker registery directly**
8. **Edit the resource usage of `istio-ingressgateway` deployment. Set CPU as 16 and memory as 40Gi.**
Note: We need to find a way to automate this step

## Deploy Istio (Build manually)
1. If the system login name is different from the docker name then, run `export DOCKER_USER=<docker name>`
2. On master node, run `./400-prerequisite.sh`
3. On master node, run `sudo docker login` to login with your dockerhub account
4. On master node run `./500-build_istio.sh` without `sudo`.
5. On master node, hardcode the dockerhub account in istio-de.yaml and then run `${MYMOUNT}/istio/out/linux_amd64/istioctl manifest install -f istio-de.yaml` to setup custom istio or run `501-install_custom_istio.sh`

To uninstall, run `${MYMOUNT}/istio/out/linux_amd64/istioctl x uninstall --purge` or run `./502-uninstall_custom_istio.sh`

## Prerequisite of KNative Serving (This is no longer needed)
1. Apply the Placement Decision CRD definition and API server permission
```
kubectl apply -f placementDecisionCrdDefinition.yaml
kubectl apply -f metric_authority.yaml
```

## Build and Setup Knative
1. If you haven't done the above steps, please complete them before moving to step 2.
2. On master node, run `./600-ko_install.sh`. Please `source ~/.bashrc` after you run the script.
3. On master node, run `./601-go_dep_install.sh`
4. On master node, run `sudo docker login` to login to your dockerhub account
5. Change permission of ko
```
sudo chown -R $(id -u):$(id -g) /users/$(id -nu)/.docker
sudo chmod g+rwx "/users/$(id -nu)/.docker" -R
```
6. **Depending on the experiment (MU, RPS or CC), modify the Knative source as instructed in section below.**
7. On master node, run `ko apply -f $GOPATH/src/knative.dev/serving/config/` to build and install knative
To uninstall, run `ko delete -f $GOPATH/src/knative.dev/serving/config/`

## Clean up Knative and Istio
1. The termination of the `knative-serving` namespace takes a long time. Please be paitent before the `knative-serving` namespace gets terminated.
2. Run `ko delete -f $GOPATH/src/knative.dev/serving/config/` to kill all Knative pods. Waiting before all the KNative pods get killed
3. run `kubectl get ns`. Wait until `knative-serving` ns gets killed.
4. Run `${MYMOUNT}/istio/out/linux_amd64/istioctl x uninstall --purge` or `./502-uninstall_custom_istio.sh` to uninstall Istio. Waiting before all the Istio pods get killed
5. Run `./500-build_istio.sh` without `sudo`.
6. Run `./501-install_custom_istio.sh`

## Experiment Setup: MU, RPS, CC
### Install loadtest
1. Clone loadtest in ucr-serverless and move to loadtest dir
```
git clone https://github.com/ucr-serverless/mu-loadtest.git loadtest
cd loadtest
```
2. Install loadtest dependencies
```
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
sudo apt install -y nodejs
npm install stdio log testing websocket confinode agentkeepalive https-proxy-agent
```
3. Loadtest command for experiment-1 and experiment-2
```
node sample/knative-variable-rps1.js > Workload1LOG & node sample/knative-variable-rps2.js > Workload2LOG &
```

### MU
1. **Modify the service YAML file:** Change CPU/Mem usage if necessary. Change autoscaling policy to `custom2`. Check SLO value, target value, etc.
2. Experiment preparation:
        - Re-build Knative if any changes has been made: `ko apply -f config/`
        - Apply service YAML: `kubectl apply -f service.yaml`
        - Start VLOG in autoscaler
        - Rename loadtest log if needed

### RPS/CC
1. **Modify the service YAML file:** Change CPU/Mem usage if necessary. Change autoscaling policy to `rps` or `concurrency`. Check SLO value, target value, etc.
2. Make sure you are using `e1bd60b2e8cae46dec00d939c1860deb4b5f586c` branch in Knative. Otherwise, do `git checkout e1bd60b2e8cae46dec00d939c1860deb4b5f586c`
3. Do `git apply defaultChanges.go` after checkout to `e1bd60b2e8cae46dec00d939c1860deb4b5f586c`
4. Experiment preparation:
        - Re-build Knative if any changes has been made: `ko apply -f config/`
        - Apply service YAML: `kubectl apply -f service.yaml`
        - Start VLOG in autoscaler
        - Rename loadtest log if needed

