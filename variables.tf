# Prefix for the resources
variable "prefix" {
  type    = string
  default = "Cloud-SOC"
}

variable "url" {
  type    = string
  default = "https://"
}

variable "sub-ID" {
  type = string


}

variable "tenant_id" {
  type = string


}

variable "rg-name" {
  type    = string
  default = "Cloud-SOC-Resources"

}

variable "la-name" {
  type    = string
  default = "Cloud-SOC-LogAnalytics"
}
