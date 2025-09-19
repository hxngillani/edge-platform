# Edge Platform – Reproducible IoT Data Pipeline

This repository provides a **reproducible, GitOps-driven edge data pipeline**.
It automates Kubernetes installation (RKE2), GitOps setup with FluxCD, and deployment of:

* **Mosquitto** – Lightweight MQTT broker
* **Node-RED** – Flow-based programming for IoT
* **InfluxDB 2.x** – Time-series database
* **Grafana** – Dashboards & visualization

With a single command, you get a fully working IoT observability stack that is **repeatable, configurable, and production-ready**.

---

## 📑 Table of Contents

* [📋 Prerequisites](#-prerequisites)

  * [Install Required Packages](#install-required-packages)
* [🚀 Installation](#-installation)

  * [1. Clone the Repository](#1-clone-the-repository)
  * [2. Install RKE2 (Kubernetes)](#2-install-rke2-kubernetes)
  * [3. Render Kubernetes Manifests](#3-render-kubernetes-manifests)
  * [4. Bootstrap Flux (GitOps)](#4-bootstrap-flux-gitops)
  * [5. Add Flux Deploy Key](#5-add-flux-deploy-key)
  * [6. Reconcile and Deploy](#6-reconcile-and-deploy)
* [🌐 Accessing Web UIs](#-accessing-web-uis)

  * [Grafana](#grafana)
  * [InfluxDB](#influxdb)
  * [Node-RED](#node-red)
* [📊 Loading Demo Dataset](#-loading-demo-dataset)
* [⚙️ Customization & GitOps Workflow](#️-customization--gitops-workflow)
* [🧹 Cleanup & Reset Options](#-cleanup--reset-options)
* [📖 Notes](#-notes)

---

## 📋 Prerequisites

* Fresh **Ubuntu 22.04+** machine (VM or physical host)
* Minimum: **2 CPU cores, 4GB RAM, 20GB disk**
* `sudo` privileges
* Internet access (to pull container images)

### Install Required Packages

```bash
sudo apt update
sudo apt install -y git ansible curl ca-certificates gnupg lsb-release
```

### Disable Firewall (recommended for local dev)

```bash
sudo systemctl stop ufw
sudo systemctl disable ufw
```

---

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone git@github.com:hxngillani/edge-platform.git
cd edge-platform
```

👉 Use the **SSH URL** (`git@github.com:...`) so it matches the Flux setup.

---

### 2. Install RKE2 (Kubernetes)

```bash
make k8s-install
```

After installation, configure kubeconfig for your user:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

Verify:

```bash
kubectl get nodes
```

---

### 3. Render Kubernetes Manifests

```bash
make generate
```

This step:

* Reads values from `vars/main.yml`
* Renders templates into `clusters/dev`
* Prepares namespaces, secrets, and HelmRelease manifests

---

### 4. Bootstrap Flux (GitOps)

```bash
export KUBECONFIG=~/.kube/config
flux bootstrap git \
  --url=ssh://git@github.com/hxngillani/edge-platform \
  --branch=main \
  --path=clusters/dev
```

This will create a **deploy key inside the cluster**, which you must add to GitHub.

---

### 5. Add Flux Deploy Key

Get Flux’s public key:

```bash
kubectl -n flux-system get secret flux-system \
  -o jsonpath="{.data.identity\.pub}" | base64 -d
```

Add this to your GitHub repo:

* Go to **Settings → Deploy keys**
* Click **Add deploy key**
* Paste the key
* ✅ Check **Allow write access**

---

### 6. Reconcile and Deploy

Once the key is added, tell Flux to retry:

```bash
flux reconcile source git flux-system -n flux-system
```

Then sync workloads:

```bash
make flux
```

---

## 🌐 Accessing Web UIs

Use **port-forwarding** to open UIs locally.

### Grafana

```bash
kubectl -n observability port-forward svc/grafana 3000:80
```

➡️ [http://localhost:3000](http://localhost:3000)
**Credentials:** `hassan / test12345`

---

### InfluxDB

```bash
kubectl -n observability port-forward svc/influxdb2 8086:80
```

➡️ [http://localhost:8086](http://localhost:8086)
**Credentials:** `hassan / test12345`
Org: `hassan`
Bucket: `telemetry`

---

### Node-RED

```bash
kubectl -n iot port-forward svc/nodered 1880:1880
```

➡️ [http://localhost:1880](http://localhost:1880)

---

## 📊 Loading Demo Dataset

```bash
kubectl apply -f clusters/dev/releases/demo-dataset.yaml
```

Check InfluxDB for `cpu_temp` and `hailo_temp` metrics.
Remove later:

```bash
kubectl -n iot delete deployment demo-publisher
```

---

## ⚙️ Customization & GitOps Workflow

Edit `vars/main.yml` and re-render.

Example:

```yaml
edge:
  influxdb:
    org: my-org
    bucket: my-bucket
    admin_user: myuser
    admin_password: strongpassword
    token: my-dev-token
```

Then:

```bash
make generate
git add -A
git commit -m "chore: update configuration"
git push origin main
make flux
```

Flux applies automatically.

---

## 🧹 Cleanup & Reset Options

### A) Remove app stack (keep cluster)

```bash
flux suspend kustomization flux-system -n flux-system || true
kubectl delete ns iot observability --ignore-not-found
kubectl delete ns flux-system --ignore-not-found
```

### B) Remove Flux only

```bash
flux uninstall --namespace flux-system --silent || true
kubectl delete ns flux-system --ignore-not-found
```

### C) Full cluster reset

```bash
sudo systemctl stop rke2-server rke2-agent || true
sudo systemctl disable rke2-server rke2-agent || true

mount | grep /var/lib/kubelet && \
  sudo umount -lf $(mount | awk '/\/var\/lib\/kubelet/ {print $3}') || true

sudo rm -rf \
  /etc/rancher/rke2 \
  /var/lib/rancher/rke2 \
  /var/lib/kubelet \
  /var/lib/etcd \
  /etc/cni \
  /opt/cni \
  ~/.kube/config

sudo rm -f /usr/local/bin/kubectl /usr/local/bin/crictl /usr/local/bin/ctr

for i in $(ip -o link show | awk -F': ' '/^ *[0-9]+: cali|flannel/ {print $2}' | sed 's/@.*//'); do
  sudo ip link delete "$i" || true
done

cd ..
rm -rf edge-platform
sudo reboot
```

---

## 📖 Notes

* `kubectl get pods -A` → check status
* `kubectl logs -n <ns> <pod>` → debug
* All workloads are GitOps-managed by Flux
