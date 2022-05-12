#creating vpcnetwork
resource "google_compute_network" "vpc_network" {
    name                    = var.vpc_network
    auto_create_subnetworks = "false"
}
#creating custom subnetwork with enable vpc flow logs
resource "google_compute_subnetwork" "vpc_subnetwork" {
    name = var.vpc_subnetwork
    network = var.vpc_network
    region = "us-west1"
    ip_cidr_range = "10.1.3.0/24"
    #flow_logs="true"

    #log aggregation of subnetwork in vpc network
    log_config{
        aggregation_interval = "INTERVAL_5_SEC"
        #flow_logs="true"
        flow_sampling = 0.5
        metadata = "INCLUDE_ALL_METADATA"
    }
}


#creating firewall rules of the vpc network 
resource "google_compute_firewall" "allow_http_ssh" {
    name = "allow-http-ssh"
    network = var.vpc_network
    target_tags = ["http-server"]
    source_ranges = ["0.0.0.0/0"]
#allowing tcp protocol with required ports    
    allow {
        protocol = "tcp"
        ports = ["80","22"]
    }
}


#creating instance
resource "google_compute_instance" "default" {
    name         = "terraform-web-server"
    zone         = "us-west1-a"
    machine_type =  "f1-micro"
    boot_disk {
        initialize_params{
            image = "debian-cloud/debian-9"
        }
    }
    network_interface {
        network = var.vpc_network
        subnetwork = var.vpc_subnetwork
        access_config {
            #allocate a one-to-one NAT IP to the instance
        }
    }
    metadata_startup_script = "sudo apt-get update && sudo apt-get install apache2 -y && echo '<!doctype  html><html><body><h1>Hello World!</h1></body></html>'| sudo tee/var/www/html/index.html"
        
        #apply the firewall rule to allow external IPs to access this instance
        tags = ["http-server"]

}

#enabling audit logs
resource "google_project_iam_audit_config" "project" {
    project = var.project
    service = "storage.googleapis.com"
    audit_log_config {
        log_type ="ADMIN_READ"
    }
    audit_log_config {
        log_type = "DATA_WRITE"
    }
    audit_log_config{
        log_type = "DATA_READ"
        exempted_members =[
        ]
    }
}

#creating dataset
resource "google_bigquery_dataset" "default" {
    dataset_id = "terraformdataset"
    friendly_name = "terraformdataset"
    location = "EU"

    labels = {
        env = "default"
    }
}

#creating sink

resource "google_logging_project_sink" "default" {
    name = "vpc_flows"
    description = "exporting logs to bigquery"
    destination ="bigquery.googleapis.com/projects/strange-retina-346405/datasets/${google_bigquery_dataset.default.dataset_id}"
    filter = "resource.type=(gce_subnetwork OR gcs_bucket) AND logName=projects/strange-retina-346405/logs/compute.googleapis.com%2Fvpc_flows OR projects/strange-retina-346405/logs/cloudaudit.googleapis.com%2Factivity"
    
    #whether or not to create a unique indentity with this sink
    unique_writer_identity = true
}

resource "google_project_iam_member" "log_writer" {
    project = var.project
    role = "roles/bigquery.dataEditor"
    member = google_logging_project_sink.default.writer_identity
}