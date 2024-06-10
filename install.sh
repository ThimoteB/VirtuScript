#!/bin/bash
set -eo pipefail

if ! command -v docker &> /dev/null
then
    echo "Docker n'est pas installé. Veuillez l'installer et réessayer."
    exit 1
fi

DOCKER_VERSION=$(docker -v | cut -d ' ' -f3 | cut -d ',' -f1)
REQUIRED_DOCKER_VERSION="26"
if [ "$(printf '%s\n' "$REQUIRED_DOCKER_VERSION" "$DOCKER_VERSION" | sort -V | head -n1)" != "$REQUIRED_DOCKER_VERSION" ]; then 
    echo "La version de Docker est inférieure à la version requise ($REQUIRED_DOCKER_VERSION). Veuillez mettre à jour Docker et réessayer."
    exit 1
fi

if ! command -v dialog &> /dev/null
then
    echo "Dialog n'est pas installé. Veuillez l'installer et réessayer."
    exit 1
fi

# Function to download files from GitHub
download_files() {
    local repo=$1
    local path=$2
    local branch=${3:-main}
    local files=($4)
    
    for file in "${files[@]}"; do
        url="https://raw.githubusercontent.com/${repo}/${branch}/${path}/${file}"
        curl -s -O "$url" || { echo "Failed to download $file from $url"; exit 1; }
    done
}

# Prompt user for environment variables
prompt_env_variables() {
    local env_file=$1
    local variables=$(grep -oP '^[A-Z0-9_]+(?==)' "$env_file")
    
    for var in $variables; do
        read -p "Please enter value for $var: " value
        sed -i "s|^$var=.*|$var=$value|" "$env_file"
    done
}

# Download required files
REPO="ThimoteB/VirtuScript"
BRANCH="main"
BASE_PATH=""

FILES=("Dockerfile" "docker-compose.yaml" ".env")

# Create directories for selected technologies and download files
declare -A tech_paths=( ["1"]="php" ["2"]="pma" ["3"]="mailpit" ["4"]="node" )

cmd=(dialog --keep-tite --checklist "Choix des images que vous voulez installer : " 22 76 16)
options=(1 "PHP" off
         2 "APACHE" off
         3 "PMA" off
         4 "MAILPIT" off
         5 "NODE" off)
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

mkdir -p VirtuScript
cd VirtuScript

for choice in $choices; do
    tech_path=${tech_paths[$choice]}
    mkdir -p "$tech_path"
    cd "$tech_path"
    download_files "$REPO" "$BASE_PATH/$tech_path" "$BRANCH" "${FILES[@]}"
    prompt_env_variables ".env"
    docker-compose up -d
    cd ..
done
ls