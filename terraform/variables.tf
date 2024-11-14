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

