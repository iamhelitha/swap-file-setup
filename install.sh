#!/bin/bash

# Welcome message
clear
echo -e "\e[1;34m==============================\e[0m"
echo -e "\e[1;32m  SWAP FILE SETUP FOR VPS  \e[0m"
echo -e "\e[1;34m==============================\e[0m"
echo

# Check if swap is already enabled
if swapon --show | grep -q "/swapfile"; then
    current_swap=$(free -h | grep Swap | awk '{print $2}')
    echo -e "\e[1;33m[!]\e[0m Swap is already enabled with size: $current_swap"
    read -p "Do you want to update the swap size? (y/n) [default: n]: " update_swap
    update_swap=${update_swap:-n}
    
    if [[ $update_swap == "y" || $update_swap == "Y" ]]; then
        # Turn off swap
        echo -e "\n\e[1;34m[*]\e[0m Turning off existing swap..."
        sudo swapoff /swapfile
    else
        echo -e "\n\e[1;32m[✓]\e[0m Keeping existing swap configuration."
        exit 0
    fi
fi

# Ask user for swap size
read -p "Enter swap size (e.g., 1G, 512M) [default: 1G]: " swapsize
swapsize=${swapsize:-1G}
echo -e "\n\e[1;34m[*]\e[0m Creating a $swapsize swap file at /swapfile...\n"

# Create swap file (or recreate if updating)
if [ -f /swapfile ]; then
    echo -e "\e[1;34m[*]\e[0m Removing old swap file..."
    sudo rm /swapfile
fi

# Create swap file
if ! sudo fallocate -l $swapsize /swapfile; then
    echo -e "\e[1;33m[fallback]\e[0m fallocate failed, using dd instead..."
    size_mb=$(echo $swapsize | grep -o -E '[0-9]+')
    unit=$(echo $swapsize | grep -o -E '[A-Za-z]+')
    if [[ $unit == "G" || $unit == "g" ]]; then
        size_mb=$((size_mb * 1024))
    fi
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$size_mb
fi

# Set correct permissions
sudo chmod 600 /swapfile

# Set up swap space
echo -e "\e[1;34m[*]\e[0m Formatting swap file..."
if ! sudo mkswap /swapfile; then
    echo -e "\e[1;31m[✗]\e[0m Failed to format swap file!"
    exit 1
fi

echo -e "\e[1;34m[*]\e[0m Activating swap file..."
if ! sudo swapon /swapfile; then
    echo -e "\e[1;31m[✗]\e[0m Failed to activate swap file!"
    exit 1
fi

# Persist the swap file
if ! grep -q "/swapfile" /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Ask user for swappiness and cache pressure with defaults
read -p "Set vm.swappiness (default: 10): " swappiness
swappiness=${swappiness:-10}
read -p "Set vm.vfs_cache_pressure (default: 50): " cache_pressure
cache_pressure=${cache_pressure:-50}

# Optimize swap usage
sudo sysctl vm.swappiness=$swappiness
sudo sysctl vm.vfs_cache_pressure=$cache_pressure

# Persist sysctl settings
if grep -q "vm.swappiness" /etc/sysctl.conf; then
    sudo sed -i "s/^vm.swappiness=.*/vm.swappiness=$swappiness/" /etc/sysctl.conf
else
    echo "vm.swappiness=$swappiness" | sudo tee -a /etc/sysctl.conf
fi

if grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
    sudo sed -i "s/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=$cache_pressure/" /etc/sysctl.conf
else
    echo "vm.vfs_cache_pressure=$cache_pressure" | sudo tee -a /etc/sysctl.conf
fi

# Verify swap is active
echo -e "\e[1;34m[*]\e[0m Verifying swap activation..."
if ! swapon --show | grep -q "/swapfile"; then
    echo -e "\e[1;31m[✗]\e[0m Swap file verification failed! Swap is not active."
    exit 1
fi

# Final message
echo -e "\n\e[1;32m[✓]\e[0m Swap successfully ${update_swap:+updated}${update_swap:-enabled} with $swapsize!"
free -h
