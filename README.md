# Edge Platform – Reproducible IoT Data Pipeline

This repository provides a **reproducible, GitOps-driven edge data pipeline**.  
It automates Kubernetes installation (RKE2), GitOps setup with FluxCD, and deployment of:

- **Mosquitto** – Lightweight MQTT broker
- **Node-RED** – Flow-based programming for IoT
- **InfluxDB 2.x** – Time-series database
- **Grafana** – Dashboards & visualization

With a single command, you get a fully working IoT observability stack that is **repeatable, configurable, and production-ready**.

---

## 📑 Table of Contents

- [📋 Prerequisites](#-prerequisites)
- [🚀 Installation](#-installation)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Install RKE2 (Kubernetes)](#2-install-rke2-kubernetes)
  - [3. Render Kubernetes Manifests](#3-render-kubernetes-manifests)
  - [4. Bootstrap Flux (GitOps)](#4-bootstrap-flux-gitops)
  - [5. Reconcile and Deploy](#5-reconcile-and-deploy)
- [🌐 Accessing Web UIs](#-accessing-web-uis)
  - [Grafana](#grafana)
  - [InfluxDB](#influxdb)
  - [Node-RED](#node-red)
- [📊 Loading Demo Dataset](#-loading-demo-dataset)
- [⚙️ Customization & GitOps Workflow](#️-customization--gitops-workflow)
- [🧹 Cleanup & Reset Options](#-cleanup--reset-options)
- [📖 Notes](#-notes)

---

## 📋 Prerequisites

- Fresh **Ubuntu 22.04+** machine (VM or physical host)
- Minimum: **2 CPU cores, 4GB RAM, 20GB disk**
- `sudo` privileges
- Internet access (to pull container images)

### Install Required Packages

```bash
sudo apt update
sudo apt install -y git ansible curl ca-certificates gnupg lsb-release
````

### Disable Firewall (Recommended for Local Dev)

```bash
sudo systemctl stop ufw
sudo systemctl disable ufw
```

---

## 🚀 Installation

Follow these steps to install and deploy the full stack.

### 1. Clone the Repository

```bash
git clone https://github.com/hxngillani/edge-platform.git
cd edge-platform
```

### 2. Install RKE2 (Kubernetes)

```bash
make k8s-install
```

# Copy kubeconfig to your user
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verify access
kubectl get nodes

This will:

* Install RKE2 (lightweight Kubernetes)
* Configure Calico CNI
* Set cluster CIDRs
* Start Kubernetes services

### 3. Render Kubernetes Manifests

```bash
make generate
```

This step:

* Reads values from `vars/main.yml`
* Renders all templates into `clusters/dev`
* Prepares namespaces, secrets, and HelmRelease manifests

### 4. Bootstrap Flux (GitOps)

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
flux bootstrap git \
  --url=https://github.com/hxngillani/edge-platform \
  --branch=main \
  --path=clusters/dev
```

This step connects your cluster to the GitHub repo so that changes are automatically applied.

### 5. Reconcile and Deploy

```bash
make flux
```

This triggers Flux to pull the latest manifests and deploy them to your cluster.

---

## 🌐 Accessing Web UIs

Once everything is deployed, you can access the UIs locally using port-forwarding.

### Grafana

```bash
kubectl -n observability port-forward svc/grafana 3000:80
```

➡️ Open **[Grafana Dashboard](http://localhost:3000)**

**Credentials:**

* **Username:** `hassan`
* **Password:** `test12345`

---

### InfluxDB

```bash
kubectl -n observability port-forward svc/influxdb2 8086:80
```

➡️ Open **[InfluxDB UI](http://localhost:8086)**

**Credentials:**

* **Username:** `hassan`
* **Password:** `test12345`
* **Org:** `hassan`
* **Bucket:** `telemetry`

---

### Node-RED

```bash
kubectl -n iot port-forward svc/nodered 1880:1880
```

➡️ Open **[Node-RED UI](http://localhost:1880)**

---

## 📊 Loading Demo Dataset

To simulate incoming telemetry data:

```bash
kubectl apply -f clusters/dev/releases/demo-dataset.yaml
```

You should now see `cpu_temp` and `hailo_temp` measurements appearing in InfluxDB, and Grafana dashboards will populate automatically.

To remove the demo workload later:

```bash
kubectl -n iot delete deployment demo-publisher
```

---

## ⚙️ Customization & GitOps Workflow

You’ll edit `vars/main.yml` and then render manifests with `make generate`.
**How Flux picks up those changes depends on which repo your cluster is watching.**

### ✅ Recommended: You bootstrapped Flux to *your own* GitHub repository (fork)

1. Edit your config:

```bash
nano vars/main.yml
make generate
```

2. Commit & push to **your repo** (the one you passed to `flux bootstrap git`):

```bash
git add -A
git commit -m "chore: update configuration"
git push origin main
```

3. Reconcile (optional; Flux would auto-sync anyway):

```bash
make flux
```

> Flux is watching your repo’s `clusters/dev` path. When you push, Flux applies the changes.

---

### 🔁 If you accidentally bootstrapped Flux to **someone else’s repo** (can’t push)

You have two good options:

**Option A — Re-bootstrap Flux to your fork (recommended):**

```bash
# Make a fork on GitHub first, then:
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
flux bootstrap git \
  --url=ssh://git@github.com/hxngillani/edge-platform \
  --branch=main \
  --path=clusters/dev
```

> Make sure your SSH key (`~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`) is added to your GitHub account under **Settings → SSH and GPG keys**.

Now repeat the steps in the “Recommended” path above (edit → `make generate` → commit → push → `make flux`).

**Option B — Retarget the existing Flux GitRepository to your fork:**

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl -n flux-system patch gitrepository flux-system \
  --type=merge \
  -p '{"spec":{"url":"https://github.com/<YOUR_GH_USER>/edge-platform"}}'
```

Then commit/push to **your fork** and `make flux`.

> ⚠️ Avoid trying to “apply locally” without Flux. Many resources here are **HelmReleases**, which require Flux controllers. The simplest, most reproducible path is to point Flux at **your** repo.

---

### Example `vars/main.yml` overrides

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
git commit -m "chore: update vars"
git push origin main
make flux
```

Flux will reconcile and apply your changes automatically.

---

## 🧹 Cleanup & Reset Options

Depending on how deep you want to clean the system, pick one of the following:

### A) Remove the Application Stack (keep cluster)

```bash
# Suspend GitOps
flux suspend kustomization flux-system -n flux-system || true

# Remove workloads
kubectl delete ns iot observability --ignore-not-found

# Optionally remove Flux itself
kubectl delete ns flux-system --ignore-not-found
```

---

### B) Remove Flux Components Only

```bash
# Uninstall Flux controllers
flux uninstall --namespace flux-system --silent || true

# Delete namespace
kubectl delete ns flux-system --ignore-not-found
```

---

### C) Full Cluster Reset (RKE2 + CNI)

This will **wipe Kubernetes completely** from your machine.

```bash
# Stop RKE2 services
sudo systemctl stop rke2-server rke2-agent || true
sudo systemctl disable rke2-server rke2-agent || true

# Unmount kubelet pod volumes (force if needed)
mount | grep /var/lib/kubelet && \
  sudo umount -lf $(mount | awk '/\/var\/lib\/kubelet/ {print $3}') || true

# Remove data directories
sudo rm -rf \
  /etc/rancher/rke2 \
  /var/lib/rancher/rke2 \
  /var/lib/kubelet \
  /var/lib/etcd \
  /etc/cni \
  /opt/cni \
  ~/.kube/config

# Remove binaries
sudo rm -f /usr/local/bin/kubectl /usr/local/bin/crictl /usr/local/bin/ctr

# Remove leftover CNI links (Calico/Flannel veths)
for i in $(ip -o link show | awk -F': ' '/^ *[0-9]+: cali|flannel/ {print $2}' | sed 's/@.*//'); do
  echo "Deleting $i"; sudo ip link delete "$i" || true
done

# Clean up repo clone (if desired)
cd ..
rm -rf edge-platform

# Reboot is the cleanest way to ensure everything is gone
sudo reboot
```

---

👉 After a reboot, you can start again from [Installation](#-installation) for a completely fresh setup.

---

## 📖 Notes

* Use `kubectl get pods -A` to monitor deployment status.
* Use `kubectl logs -n <namespace> <pod>` to debug failures.
* All components are declaratively defined — changes in Git are automatically synced.
