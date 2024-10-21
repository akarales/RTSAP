Copy# Real-Time Streaming Analytics Platform (RTSAP) Setup Guide

This guide provides comprehensive instructions for setting up the RTSAP on a fresh Ubuntu 24.04 system.

## Prerequisites

- A machine running Ubuntu 24.04 LTS
- Sudo privileges
- Internet connection
- At least 16GB RAM and 4 CPU cores (more recommended for production use)

## 1. System Update and Essential Tools

Update the system and install essential tools:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential curl wget git zsh
```

2. Install Java
Install Java 11:
bashCopysudo apt install -y openjdk-11-jdk
Verify the Java installation:
bashCopyjava -version
3. Install Docker
Install Docker:
bashCopysudo apt install -y apt-transport-https ca-certificates gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
Log out and log back in for the group changes to take effect.
4. Install Minikube
Install Minikube v1.33.0:
bashCopycurl -LO https://github.com/kubernetes/minikube/releases/download/v1.33.0/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
5. Install kubectl
Install kubectl v1.30.0:
bashCopycurl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
6. Install k9s
Install k9s v0.32.4:
bashCopywget https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz
7. Install Helm
Install Helm:
bashCopycurl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
8. Start Minikube
Start Minikube:
bashCopyminikube start --cpus 4 --memory 8192
9. Set up Helm Repositories
Add necessary Helm repositories:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add apache https://charts.apache.org
helm repo add timescale https://charts.timescale.com
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add qdrant https://qdrant.github.io/qdrant-helm
helm repo update
```

10. Install Core Services
Install the core services using Helm:

```bash
helm install my-kafka bitnami/kafka
helm install my-flink bitnami/flink
helm install my-spark bitnami/spark
helm install my-mongodb bitnami/mongodb
helm install my-postgres bitnami/postgresql
helm install my-timescaledb timescale/timescaledb
helm install my-minio bitnami/minio
helm install my-jupyterhub jupyterhub/jupyterhub
helm install my-argo-workflows argo/argo-workflows
helm install my-prometheus prometheus-community/prometheus
helm install my-grafana grafana/grafana
helm install my-loki grafana/loki
helm install my-qdrant qdrant/qdrant
```

11. Install and Configure Apache Spark
Install Apache Spark:
bashCopycurl -O https://downloads.apache.org/spark/spark-3.5.1/spark-3.5.1-bin-hadoop3.tgz
tar xvf spark-3.5.1-bin-hadoop3.tgz
sudo mv spark-3.5.1-bin-hadoop3 /opt/spark
echo "export SPARK_HOME=/opt/spark" >> ~/.bashrc
echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> ~/.bashrc
source ~/.bashrc
Configure Spark for Kubernetes:
bashCopykubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
12. Install and Configure Jenkins
Install Jenkins:
bashCopywget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install -y jenkins
Start Jenkins service:
bashCopysudo systemctl start jenkins
sudo systemctl enable jenkins
Retrieve the initial admin password:
bashCopysudo cat /var/lib/jenkins/secrets/initialAdminPassword
Access Jenkins through your web browser at http://your_server_ip:8080 and follow the setup wizard.
13. Set Up Data API Service
Create a new directory for the Data API service:
bashCopymkdir -p ~/rtsap/data-api
cd ~/rtsap/data-api
Create a Python virtual environment and install FastAPI:
bashCopypython3 -m venv venv
source venv/bin/activate
pip install fastapi uvicorn
Create a basic FastAPI application (app.py):
pythonCopyfrom fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Welcome to RTSAP Data API"}

# Add more endpoints as needed
Create a Dockerfile for the Data API service:
DockerfileCopyFROM python:3.9

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
Build and push the Docker image:
bashCopydocker build -t your-docker-registry/rtsap-data-api:v1 .
docker push your-docker-registry/rtsap-data-api:v1
Deploy the Data API service to Kubernetes:
bashCopykubectl create deployment data-api --image=your-docker-registry/rtsap-data-api:v1
kubectl expose deployment data-api --type=LoadBalancer --port=8000
14. Install Additional Tools
Install Python and necessary libraries:
bashCopysudo apt install python3 python3-pip
pip3 install pandas numpy matplotlib seaborn scikit-learn jupyter
Install Apache Mahout:
bashCopywget https://downloads.apache.org/mahout/0.13.0/apache-mahout-distribution-0.13.0.tar.gz
tar -xzvf apache-mahout-distribution-0.13.0.tar.gz
sudo mv apache-mahout-distribution-0.13.0 /opt/mahout
echo "export MAHOUT_HOME=/opt/mahout" >> ~/.bashrc
echo "export PATH=\$PATH:\$MAHOUT_HOME/bin" >> ~/.bashrc
source ~/.bashrc
Install Apache MXNet:
bashCopypip3 install mxnet
Install Apache OpenNLP:
bashCopywget https://downloads.apache.org/opennlp/opennlp-2.3.0/apache-opennlp-2.3.0-bin.tar.gz
tar -xzvf apache-opennlp-2.3.0-bin.tar.gz
sudo mv apache-opennlp-2.3.0 /opt/opennlp
echo "export OPENNLP_HOME=/opt/opennlp" >> ~/.bashrc
echo "export PATH=\$PATH:\$OPENNLP_HOME/bin" >> ~/.bashrc
source ~/.bashrc
15. Configure Services
After installation, configure each service according to your specific requirements. Refer to the official documentation of each tool for detailed configuration instructions.
16. Set Up Development Environment
Install an IDE (e.g., VS Code):
bashCopysudo snap install --classic code
17. Verify Installation
Verify that all services are running:
bashCopykubectl get pods --all-namespaces
You can also use k9s to interactively manage your Kubernetes cluster:
bashCopyk9s
Final Steps

Configure your local environment to connect to the Kubernetes cluster.
Set up your Jenkins pipelines for CI/CD.
Start developing your data analytics applications.
Use Argo Workflows to orchestrate your data processing pipelines.

Troubleshooting

If pods are not starting, check the logs:
bashCopykubectl logs <pod-name>

For persistent issues, check the Minikube status:
bashCopyminikube status

Use k9s for interactive troubleshooting and management of your Kubernetes resources.
Ensure your machine has sufficient resources to run all services.

Remember to consult the official documentation for each tool for more detailed configuration and usage instructions. This setup provides a foundation for your RTSAP. You may need to further customize and optimize based on your specific requirements and scale of operations.