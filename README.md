<div align="center">
  <h1>
    Terraform demo
  </h1>

<h4>
    Aprovisionar recursos en Azure usando Terraform
  </h4>

[![GitHub sets018](https://img.shields.io/badge/by-slrosales-green)](https://github.com/slrosales)
[![GitHub jfbenitezz](https://img.shields.io/badge/by-jfbenitezz-purple)](https://github.com/jfbenitezz)
[![GitHub FernandoMVG](https://img.shields.io/badge/by-FernandoMVG-blue)](https://github.com/FernandoMVG)

</div>

## Introducción y objetivos de la demo

En esta demostración, desplegaremos una infraestructura en Azure utilizando archivos .tf personalizados. El objetivo es crear una máquina virtual Linux y conectarse a ella por SSH para instalar un servidor Nginx y activar un sitio web simple.

## Preparación del entorno de trabajo

### Instalación del Azure CLI

1. Actualiza el índice de paquetes:

```
sudo apt update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```
2. Ejecuta el comando

```
az --version
```
y comprueba que se ha instalado correctamente

### Instalación y Autenticación de Terraform en Azure

1. En linux, ejecuta los siguientes comandos en la terminal

```
sudo apt update
sudo snap install terraform --classic 
```
2. Para comprobar que se ha instalado exitosamente puedes ejecutar el siguiente comando

```
terraform --version
```

3. Creamos un directorio para contener nuestros archivos de terraform

```
mkdir Terraform
cd Terraform
```

### Autenticación de Terraform en azure (mediante una cuenta de microsoft)

1. Ejecuta 

```
az login
```

2. En caso de tener distintas suscripciones, puedes establecer con que suscripción vas a trabajar. Ejecuta el comando para mostrar tus suscripciones y para establecer la suscripción con la que trabajaras

```
az account show
az account set --subscription "<subscription_id_or_subscription_name>"
```

### Aprovisionamiento de la infraestructura en Azure

1. Crearemos un archivo `nano provider.tf`:

```
terraform {
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

```

Este archivo:
* Define la versión mínima requerida de Terraform (>=0.12)
* Especifica los proveedores necesarios y sus versiones:
   - azapi: Proveedor para la API de Azure
   - azurerm: Proveedor principal de Azure Resource Manager
   - random: Proveedor para generar valores aleatorios
* Configura el proveedor azurerm con configuraciones básicas

2. Ahora creamos otro archivo llamado `nano ssh.tf`:

```
resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
}

# Save the SSH private key to a local file
resource "local_file" "ssh_private_key" {
  content  = azapi_resource_action.ssh_public_key_gen.output.privateKey
  filename = "${path.module}/generated_ssh_key.pem"
  file_permission = "0600" # Secure file permissions
}
```

El archivo `ssh.tf` gestiona la creación y configuración de las claves SSH:

* Genera un nombre aleatorio para la clave SSH usando `random_pet`
* Crea un recurso de clave pública SSH en Azure mediante `azapi_resource`
* Genera el par de claves (pública/privada) usando `azapi_resource_action`
* Guarda la clave privada en un archivo local `generated_ssh_key.pem` con los permisos adecuados (0600) para poder conectarnos a la VM

3. Creamos el archivo `nano main.tf`:

```
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Regla para SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Nueva regla para HTTP (puerto 80)
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "NeworkinVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "hostname"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

```

El archivo `main.tf` es el archivo principal de configuración de Terraform. En este archivo, definimos los recursos que queremos crear en Azure. A continuación, se detallan los componentes principales del archivo `main.tf`:

* `resource "azurerm_resource_group" "rg"`: Este bloque define un grupo de recursos en Azure.
* `resource "azurerm_virtual_network" "vnet"`: Este bloque define una red virtual en Azure.
* `resource "azurerm_subnet" "subnet"`: Este bloque define una subred dentro de la red virtual.
* `resource "azurerm_network_interface" "nic"`: Este bloque define una interfaz de red para la máquina virtual.
* `resource "azurerm_public_ip" "public_ip"`: Este bloque define una dirección IP pública para la máquina virtual.
* `resource "azurerm_network_security_group" "nsg"`: Este bloque define un grupo de seguridad de red para la máquina virtual.
* `resource "azurerm_network_security_rule" "nsg_rule"`: Este bloque define una regla de seguridad de red para permitir el tráfico SSH (puerto 22).
* `resource "azurerm_linux_virtual_machine" "vm"`: Este bloque define la máquina virtual Linux en Azure.

4. Creamos el archivo `nano variables.tf`:

```
variable "resource_group_location" {
  type        = string
  default     = "canadacentral"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random>}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the >  default     = "azureadmin"
}

```

El archivo `variables.tf` define las variables que se utilizan en los archivos de configuración de Terraform.

* `variable "resource_group_location"`: Define la ubicación del grupo de recursos en Azure. El valor predeterminado es "canadacentral". (A la fecha de creación de esta guía, las zonas de US estan dando problemas)
* `variable "resource_group_name_prefix"`: Define el prefijo del nombre del grupo de recursos que se combinará con un valor aleatorio para crear un nombre único.
* `variable "username"`: Define el nombre de usuario para la cuenta local que se creará en la máquina virtual. El valor predeterminado es "azureadmin".

5. Y por último, creamos un archivo llamado `nano outputs.tf`:

```
output "key_data" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "ssh_private_key_path" {
  value       = local_file.ssh_private_key.filename
  description = "Path to the generated SSH private key file."
}

output "ssh_public_key" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address
}
```

El archivo `outputs.tf` define las salidas que se mostrarán después de que Terraform haya aplicado la configuración. Estas salidas incluyen:

* `output "key_data"`: Muestra la clave pública SSH generada.
* `output "ssh_private_key_path"`: Muestra la ruta al archivo de clave privada SSH generada.
* `output "ssh_public_key"`: Muestra la clave pública SSH generada.
* `output "resource_group_name"`: Muestra el nombre del grupo de recursos creado.
* `output "public_ip_address"`: Muestra la dirección IP pública de la máquina virtual creada.

6. Una vez creados los archivos, ejecutamos:

```
terraform init
```

Este comando inicializa el repositorio, es decir, inicializa el backend, instala los providers y verifica la configuración de los demas archivos.

7. Con el comando `terraform plan`:

```
terraform plan
```

Se genera una serie de archivos que muestran los cambios que ocurriran antes de que se ejecute cualquier acción. Este comando permite visualizar el plan de ejecución de Terraform, mostrando los recursos que se crearán, actualizarán o eliminarán.

8. Y ya para finalizar, una vez que hayamos verificado que todo este en orden, ejecutamos `terraform apply`:

```
terraform apply
```

Para aprovisionar los recursos previamente definidos, en Azure.

9. Para verificar que recursos se aprovisionaron, o bien puedes observarlo en la interfaz de azure en los grupos de recursos o ejecutar el siguiente comando:

```

terraform state list

```

10. Y para destruir la infraestructura, ejecuta el siguiente comando:

```
terraform destroy
```

Esto eliminara todos los recursos previamente aprovisionados en Azure.

### Conectarse a la VM y configurar un servidor nginx

1. Para conectarnos a nuestra VM creada en Azure, usamos el siguiente comando:

```
ssh -i ./generated_ssh_key.pem azureadmin@<ip-publica>
```

donde reemplazas `<ip-publica>` por la ip obtenida en el output.

Debido a que estamos guardando la llave ssh dentro del directorio terraform, es necesario estar dentro del directorio para usar el comando, en caso contrario tienes que indicar la ruta hasta el archivo donde se guarda la llave genereda.

2. Instalamos nginx dentro de la VM con los siguientes comandos:

```
sudo apt update
sudo apt install nginx -y
```

Luego activamos nginx con el siguiente comando `sudo systemctl start nginx` y habilitamos su ejecución automática con `sudo systemctl start nginx`.

Para verificar el estado del servidor, usa: `sudo systemctl status nginx`

3. Crear una página web simple en el servidor Nginx

Para crear una página web simple, sigue estos pasos:

1. Navega al directorio raíz de Nginx:

```
cd /var/www/html
```

2. Crea un archivo HTML llamado `index.html`:

```
sudo nano index.html
```

3. Agrega el siguiente contenido al archivo `index.html`:

```
<!DOCTYPE html>
<html>
<head>
    <title>Bienvenido a Nginx</title>
</head>
<body>
    <h1>¡Nginx está funcionando!</h1>
    <p>Esta es una página web simple servida por Nginx en una máquina virtual de Azure.</p>
</body>
</html>
```

4. Guarda y cierra el archivo.

5. Reinicia el servidor Nginx para aplicar los cambios:

```
sudo systemctl restart nginx
```

Ahora, si accedes a la dirección IP pública de tu máquina virtual en un navegador web, deberías ver la página web simple que creaste.
