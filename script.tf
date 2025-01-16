terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

# Use QEMU/libvirt
provider "libvirt" {
  uri = "qemu:///system"
}

# Create storage pool
resource "libvirt_pool" "vm_pool" {
  name = "vm_pool"
  type = "dir"
  path = "${path.cwd}/pool/images/terraform-provider-libvirt-pool-ubuntu"
}

# Define KVM network
resource "libvirt_network" "vm_network" {
  name      = "vm_network"
  mode      = "nat"
  domain    = "vm.local"
  addresses = ["10.10.10.0/24"]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

# Create a volume for the ubuntu VM
resource "libvirt_volume" "os_image" {
  name   = "os_image.qcow2"
  pool   = libvirt_pool.vm_pool.name
  source = "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img"
}

# Create a resized volume using the base image to install docker and kubernetes
resource "libvirt_volume" "disk_image_resized" {
  name           = "image_resized.qcow2"
  base_volume_id = libvirt_volume.os_image.id
  pool           = libvirt_pool.vm_pool.name
  size           = 21474836480  # 20GB in bytes
  format         = "qcow2"
}

# Create a cloud-init disk for VM configuration
resource "libvirt_cloudinit_disk" "commoninit_resized" {
  name      = "commoninit_resized.iso"
  pool      = libvirt_pool.vm_pool.name
  user_data = <<-EOF
              #cloud-config with my ssh key
              hostname: ubuntu-vm
              disable_root: 1
              ssh_pwauth: 0
              users:
                - name: userA
                  sudo: ALL=(ALL) NOPASSWD:ALL
                  shell: /bin/bash
                  ssh_authorized_keys:
                    - ${file("${path.root}/keys/id_ed25519.pub")}
              growpart:
                mode: auto
                devices: ['/']
              EOF
}

# Create the VM
resource "libvirt_domain" "vm" {
  name   = "ubuntu-vm"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit_resized.id

  network_interface {
    network_id = libvirt_network.vm_network.id
    wait_for_lease = true
    addresses  = ["10.10.10.100"] #define static ip
  }

  disk {
    volume_id = libvirt_volume.disk_image_resized.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  # Forward host port 8080 to guest port 30080 (kubernetes nodeport)
  xml {
      xslt = <<-XSLT
        <?xml version="1.0" ?>
        <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:template match="@*|node()">
        <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
        </xsl:template>
        <xsl:template match="/network-interface">
        <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
        <filterref filter="forward-ports">
        <parameter name="HOST_PORT" value="8080"/>
        <parameter name="GUEST_PORT" value="30080"/>
        <parameter name="GUEST_IP" value="192.168.49.2"/>
        <parameter name="PROTO" value="tcp"/>
        </filterref>
        </xsl:copy>
        </xsl:template>
        </xsl:stylesheet>
        XSLT
  }
}
