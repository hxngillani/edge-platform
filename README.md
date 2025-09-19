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
  * [Generate & Add SSH Key](#-generate--add-ssh-key-if-not-already-set-up)
* [🚀 Installation](#-installation)

  * [1. Clone the Repository](#1-clone-the-repository)
  * [2. Install RKE2 (Kubernetes)](#2-install-rke2-kubernetes)
  * [3. Render Kubernetes Manifests](#3-render-kubernetes-manifests)
  * [4. Bootstrap Flux (GitOps)](#4-bootstrap-flux-gitops)
  * [5. Reconcile and Deploy](#5-reconcile-and-deploy)
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

### Disable Firewall (Recommended for Local Dev)

```bash
sudo systemctl stop ufw
sudo systemctl disable ufw
```

---

### 🔑 Generate & Add SSH Key (if not already set up)

Flux works best with SSH authentication. Before bootstrapping, make sure your GitHub account has an SSH key.

1. **Check if you already have a key:**

```bash
ls ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub
```

If one of these files exists, you already have a key.

2. **Generate a new key (if none exists):**

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Press **Enter** to accept defaults. This creates `~/.ssh/id_ed25519.pub`.

3. **Copy the public key:**

```bash
cat ~/.ssh/id_ed25519.pub
```

4. **Add it to GitHub:**

* Go to [GitHub → Settings → SSH and GPG keys](https://github.com/settings/keys)
* Click **New SSH key**, paste the key, and save.

5. **Test the connection:**

```bash
ssh -T git@github.com
```

You should see:
`Hi <your-username>! You've successfully authenticated.`

---

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone git@github.com:hxngillani/edge-platform.git
cd edge-platform
```

👉 Note: we use **SSH URL** (`git@github.com:...`) instead of HTTPS.

---

### 2. Install RKE2 (Kubernetes)

```bash
make k8s-install
```

After installation, copy the kubeconfig so your user can access the cluster:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

Verify access:

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

This connects your cluster to the GitHub repo so that changes are automatically applied.

---

### 5. Reconcile and Deploy

```bash
make flux
```

This forces Flux to pull the latest manifests and apply them immediately.

---

## 🌐 Accessing Web UIs

Use **port-forwarding** to access dashboards locally.

### Grafana

```bash
kubectl -n observability port-forward svc/grafana 3000:80
```

➡️ Open **[Grafana Dashboard](http://localhost:3000)**

**Credentials:**

* Username: `hassan`
* Password: `test12345`

---

### InfluxDB

```bash
kubectl -n observability port-forward svc/influxdb2 8086:80
```

➡️ Open **[InfluxDB UI](http://localhost:8086)**

**Credentials:**

* Username: `hassan`
* Password: `test12345`
* Org: `hassan`
* Bucket: `telemetry`

---

### Node-RED

```bash
kubectl -n iot port-forward svc/nodered 1880:1880
```

➡️ Open **[Node-RED UI](http://localhost:1880)**

---

## 📊 Loading Demo Dataset

```bash
kubectl apply -f clusters/dev/releases/demo-dataset.yaml
```

You should see `cpu_temp` and `hailo_temp` metrics in InfluxDB, and Grafana dashboards will populate automatically.

Remove the demo workload later:

```bash
kubectl -n iot delete deployment demo-publisher
```

---

## ⚙️ Customization & GitOps Workflow

You’ll edit `vars/main.yml` and re-render manifests.

### Example: override InfluxDB settings

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

Flux will reconcile automatically.

---

## 🧹 Cleanup & Reset Options

Pick the level of cleanup you need.

### A) Remove Application Stack (keep cluster)

```bash
flux suspend kustomization flux-system -n flux-system || true
kubectl delete ns iot observability --ignore-not-found
kubectl delete ns flux-system --ignore-not-found
```

---

### B) Remove Flux Components Only

```bash
flux uninstall --namespace flux-system --silent || true
kubectl delete ns flux-system --ignore-not-found
```

---

### C) Full Cluster Reset (RKE2 + CNI)

```bash
# Stop services
sudo systemctl stop rke2-server rke2-agent || true
sudo systemctl disable rke2-server rke2-agent || true

# Unmount kubelet pod volumes
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

# Remove CNI links
for i in $(ip -o link show | awk -F': ' '/^ *[0-9]+: cali|flannel/ {print $2}' | sed 's/@.*//'); do
  echo "Deleting $i"; sudo ip link delete "$i" || true
done

# Optional: remove repo
cd ..
rm -rf edge-platform

# Reboot for a fully clean slate
sudo reboot
```

---

## 📖 Notes

* Use `kubectl get pods -A` to check deployment status.
* Use `kubectl logs -n <namespace> <pod>` for debugging.
* All components are GitOps-managed — changes in Git are applied automatically.
