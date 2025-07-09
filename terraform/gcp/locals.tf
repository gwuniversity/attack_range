
# locals {
#   # Map each instance ID to its sequential index
#   linux_instance_id_to_index = zipmap(
#     module.linux_server.linux_server_instance_ids,
#     range(length(module.linux_server.linux_server_instance_ids))
#   )
#   # Map each instance ID to its sequential index
#   windows_instance_id_to_index = zipmap(
#     module.windows_server.windows_server_instance_ids,
#     range(length(module.windows_server.windows_server_instance_ids))
#   )
# }