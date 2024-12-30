#!/bin/bash

# Variables
VM_ID=106                 # Proxmox VM ID
VM_NAME="diyhue"          # VM Name
VM_MEMORY=2048            # Memory in MB
VM_DISK_SIZE=10G          # Disk size
VM_CORES=2                # Number of CPU cores
VM_BRIDGE="vmbr0"         # Network bridge
VM_OS_TEMPLATE="local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"  # Adjust as needed
VM_STORAGE="local-lvm"    # Storage location

echo "Starting diyHue setup on Proxmox..."

# Step 1: Create a new Proxmox VM
echo "Creating Proxmox VM..."
pveam update
if ! pveam list local | grep -q "debian-12"; then
    echo "Debian 12 template not found. Downloading..."
    pveam download local debian-12-standard_12.0-1_amd64.tar.zst
fi

pct create $VM_ID $VM_OS_TEMPLATE --cores $VM_CORES --memory $VM_MEMORY --net0 name=eth0,bridge=$VM_BRIDGE,ip=dhcp --rootfs $VM_STORAGE:$VM_DISK_SIZE
pct start $VM_ID

# Step 2: Install Docker inside the VM
echo "Installing Docker..."
pct exec $VM_ID -- bash -c "
    apt update && apt upgrade -y
    apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable' > /etc/apt/sources.list.d/docker.list
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
"

# Step 3: Set up diyHue in Docker
echo "Setting up diyHue..."
pct exec $VM_ID -- bash -c "
    mkdir -p /mnt/diyhue/config
    docker run -d \
        --name diyHue \
        --restart=always \
        -p 80:80 \
        -p 443:443 \
        -p 2100:2100/udp \
        -p 1900:1900/udp \
        -v /mnt/diyhue/config:/opt/hue-emulator/config \
        diyhue/core:latest
"

# Step 4: Output VM details
VM_IP=$(pct exec $VM_ID -- hostname -I | awk '{print $1}')
echo "diyHue setup complete! Access it at: http://$VM_IP"

echo "Proxmox diyHue setup script finished."
