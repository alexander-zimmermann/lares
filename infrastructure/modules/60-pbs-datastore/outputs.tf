output "name" {
  description = "Name of the datastore as registered in PBS."
  value       = pbs_datastore.this.name
}

output "path" {
  description = "Absolute path of the datastore directory on the PBS VM."
  value       = pbs_datastore.this.path
}
