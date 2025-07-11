from google.auth import default
from google.cloud.compute_v1 import RegionsClient
from google.cloud import compute_v1, storage, bigtable, secretmanager
import sys
import os
import json
import time


def check_region(config_region):
    credentials, project = default()
    client = RegionsClient()

    # List regions for the project
    try:
        # Get all regions for the project
        request = compute_v1.ListRegionsRequest()
        request.project = project

        # Make the API call
        response = client.list(request=request)

        # Extract region names
        regions = [region.name for region in response]

        # Check if the configured region matches any in the project
        if config_region not in regions:
            print(
                f"Error: Region '{config_region}' is not available in project '{project}'."
            )
            print(f"Available regions are: {', '.join(regions)}")
            print("Please update your config file with one of the available regions.")
            return False

        return True
    except Exception as e:
        print(f"Error checking region: {e}")
        return False


def get_all_instances(key_name, region):
    instances = []
    credentials, project = default()
    instance_client = compute_v1.InstancesClient()

    # Get all zones in the region
    zone_client = compute_v1.ZonesClient()
    zones = [
        zone.name for zone in zone_client.list(project=project) if region in zone.name
    ]

    # Collect matching instances
    for zone in zones:
        try:
            # Get instances for this zone
            instances_list = instance_client.list(project=project, zone=zone)
            # Process the instances
            for instance in instances_list:
                if key_name in instance.name:
                    instances.append(instance)
        except Exception as e:
            print(f"Error getting instances in zone {zone}: {str(e)}")
            continue

    return instances


def get_instance_by_name(instance_name, key_name, region):
    # First get all instances using the existing function
    instances = get_all_instances(key_name, region)

    for instance in instances:
        if "labels" in instance:
            labels = instance.labels
            if "name" in labels and labels["name"] == instance_name:
                return instance

    return None  # Return None if no matching instance is found


def get_instances_by_ids(instance_ids, instance_name, key_name, ar_name, region):
    # First get all instances using the existing function
    instances = get_all_instances(key_name, region)

    result = []
    for instance in instances:
        # Check if the instance ID matches
        if instance.id in instance_ids:
            # Check if labels match ar_name
            if "labels" in instance:
                labels = instance.labels
                if ar_name in labels.values():
                    result.append(instance)

    return result


def get_single_instance_public_ip(instance_name, key_name, region):
    # First get all instances using the existing function
    return (
        get_instance_by_name(instance_name, key_name, region)
        .network_interfaces[0]
        .access_configs[0]
        .nat_i_p
    )


def change_instance_state(project_id, instances, new_state, logger):
    client = compute_v1.InstancesClient()

    if len(instances) == 0:
        logger.error("ERROR: No instances found.")
        sys.exit(1)

    for instance in instances:
        instance_name = instance.name
        zone = instance.zone.split("/")[-1]

        try:
            if new_state == "stopped" and instance.status == "RUNNING":
                operation = client.stop(
                    project=project_id, zone=zone, instance=instance_name
                )
                logger.info(
                    f"Successfully stopped instance with name {instance_name}. Operation ID: {operation.name}"
                )

            elif new_state == "running" and instance.status == "TERMINATED":
                operation = client.start(
                    project=project_id, zone=zone, instance=instance_name
                )
                logger.info(
                    f"Successfully started instance with name {instance_name}. Operation ID: {operation.name}"
                )

        except Exception as e:
            logger.error(f"Failed to change state for instance {instance_name}: {e}")


def image_available(image_name, project_id):
    client = compute_v1.ImagesClient()

    try:
        # Get the image details
        image = client.get(project=project_id, image=image_name)

        # Check if the image is in "READY" state
        if image.status == "READY":
            return True
    except Exception as e:
        # Image does not exist or another error occurred
        return False

    return False
