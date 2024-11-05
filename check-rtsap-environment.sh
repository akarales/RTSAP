#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}RTSAP Environment Checker${NC}"
echo "=================================================="

# Function to get version numbers
get_version() {
    local cmd=$1
    case $cmd in
        "minikube")
            minikube version | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | cut -dv -f2
            ;;
        "kubectl")
            kubectl version --client 2>/dev/null | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | head -1 | cut -dv -f2
            ;;
        "k9s")
            k9s version --short | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | cut -dv -f2
            ;;
        "java")
            java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | awk -F '.' '{print $1}'
            ;;
        "docker")
            docker --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1
            ;;
        "python3")
            python3 --version | awk '{print $2}'
            ;;
        "dbeaver-ce")
            dbeaver-ce --version | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" || echo "unknown"
            ;;
        "helm")
            helm version --short | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | cut -dv -f2
            ;;
    esac
}

# Function to check Java version compatibility
check_java_version() {
    local version=$1
    if [[ $version -ge 11 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check command existence and version
check_command() {
    local cmd=$1
    local required_version=$2
    
    echo -ne "Checking $cmd... "
    
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}✗ Not installed${NC}"
        return 1
    fi

    if [ -n "$required_version" ]; then
        local current_version=$(get_version $cmd)
        echo -ne "version $current_version "
        
        if [ "$cmd" = "java" ]; then
            if check_java_version "$current_version"; then
                echo -e "${GREEN}✓${NC}"
                return 0
            else
                echo -e "${RED}✗ (requires >= 11)${NC}"
                return 1
            fi
        elif [ "$current_version" = "$required_version" ]; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${YELLOW}! (expected $required_version)${NC}"
            return 2
        fi
    else
        echo -e "${GREEN}✓${NC}"
        return 0
    fi
}

# Function to check Docker group membership
check_docker_group() {
    echo -ne "Checking Docker group membership... "
    if groups $USER | grep -q docker; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗ User not in docker group${NC}"
        return 1
    fi
}

# Function to check Minikube status
check_minikube_status() {
    echo -ne "Checking Minikube status... "
    if minikube status 2>/dev/null | grep -q "Running"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${YELLOW}! Not running${NC}"
        return 1
    fi
}

# Function to check Helm repositories
check_helm_repos() {
    echo -ne "Checking Helm repositories... "
    local required_repos=("bitnami" "timescale" "jupyterhub" "argo" "prometheus-community" "grafana" "qdrant")
    local missing_repos=()

    for repo in "${required_repos[@]}"; do
        if ! helm repo list 2>/dev/null | grep -q "^$repo"; then
            missing_repos+=($repo)
        fi
    done

    if [ ${#missing_repos[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}! Missing: ${missing_repos[*]}${NC}"
        return 1
    fi
}

# Function to check project directory structure
check_project_structure() {
    echo -ne "Checking project directory structure... "
    local base_dir="$HOME/Documents/CODE/RTSAP"
    local required_dirs=("config" "scripts" "data" "notebooks" "models")
    local missing_dirs=()

    if [ ! -d "$base_dir" ]; then
        echo -e "${RED}✗ Base directory not found${NC}"
        return 1
    fi

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$base_dir/$dir" ]; then
            missing_dirs+=($dir)
        fi
    done

    if [ ${#missing_dirs[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}! Missing directories: ${missing_dirs[*]}${NC}"
        return 1
    fi
}

# Function to check deployed services
check_deployed_services() {
    echo -ne "Checking deployed services... "
    if ! kubectl get pods &> /dev/null; then
        echo -e "${YELLOW}! Cannot check services - Kubernetes not accessible${NC}"
        return 1
    fi

    local required_services=("timescaledb")
    local missing_services=()
    
    for service in "${required_services[@]}"; do
        if ! kubectl get pods 2>/dev/null | grep -q "$service"; then
            missing_services+=($service)
        fi
    done

    if [ ${#missing_services[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}! Missing services: ${missing_services[*]}${NC}"
        return 1
    fi
}

# Function to create directories if needed
create_project_structure() {
    local base_dir="$HOME/Documents/CODE/RTSAP"
    local dirs=("config" "scripts" "data" "notebooks" "models")
    
    echo -e "${BLUE}Creating project directory structure...${NC}"
    for dir in "${dirs[@]}"; do
        if [ ! -d "$base_dir/$dir" ]; then
            mkdir -p "$base_dir/$dir"
            echo -e "${GREEN}Created $dir directory${NC}"
        fi
    done
}

# Function to add helm repositories
add_helm_repos() {
    echo -e "\n${BLUE}Adding Helm repositories...${NC}"
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null
    helm repo add timescale https://charts.timescale.com 2>/dev/null
    helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/ 2>/dev/null
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null
    helm repo add qdrant https://qdrant.github.io/qdrant-helm 2>/dev/null
    helm repo update
}

# Main checks
echo -e "\n${BLUE}Checking required software...${NC}"
check_command "docker" ""
check_command "minikube" "1.33.0"
check_command "kubectl" "1.30.0"
check_command "k9s" "0.32.4"
check_command "helm" ""
check_command "java" "11"  # Now accepts Java 11 or higher
check_command "python3" ""
check_command "dbeaver-ce" ""

echo -e "\n${BLUE}Checking system configuration...${NC}"
check_docker_group
check_minikube_status
check_helm_repos
check_project_structure
check_deployed_services

# Collect issues that need fixing
declare -a issues=()
if ! check_project_structure >/dev/null; then
    issues+=("1")
fi
if ! check_helm_repos >/dev/null; then
    issues+=("2")
fi
if ! check_minikube_status >/dev/null; then
    issues+=("3")
fi
if ! check_deployed_services >/dev/null; then
    issues+=("4")
fi

if [ ${#issues[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Would you like to automatically fix the following issues?${NC}"
    echo "1. Create missing project directories"
    echo "2. Add missing Helm repositories"
    echo "3. Start Minikube (if not running)"
    echo "4. Deploy missing services"
    echo -e "\nEnter numbers to fix (e.g., '1 2 3' or 'all'), or press Enter to skip: "
    read -r fix_choice

    if [[ $fix_choice ]]; then
        if [[ $fix_choice == "all" ]] || [[ $fix_choice =~ "1" ]]; then
            create_project_structure
        fi
        
        if [[ $fix_choice == "all" ]] || [[ $fix_choice =~ "2" ]]; then
            add_helm_repos
        fi
        
        if [[ $fix_choice == "all" ]] || [[ $fix_choice =~ "3" ]]; then
            if ! minikube status | grep -q "Running"; then
                echo -e "\n${BLUE}Starting Minikube...${NC}"
                minikube start --cpus 8 --memory 40960
                minikube addons enable metrics-server
                minikube addons enable dashboard
            fi
        fi
        
        if [[ $fix_choice == "all" ]] || [[ $fix_choice =~ "4" ]]; then
            echo -e "\n${BLUE}Deploying missing services...${NC}"
            if ! kubectl get pods 2>/dev/null | grep -q "timescaledb"; then
                helm install my-timescaledb timescale/timescaledb-single
            fi
        fi
    fi
fi

echo -e "\n${GREEN}Check complete! Run the script again to verify fixes.${NC}"