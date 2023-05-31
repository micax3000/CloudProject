provider "google"{
 project			= "cloud-internship-milan"	
 region				= "us-central1"	
}

resource "google_compute_network" "main" {
 name				= "main"
 auto_create_subnetworks	= false
}

resource "google_compute_subnetwork" "main_subnet" {
  name				= "main-subnet"
  ip_cidr_range			= "10.0.0.0/24"
  network			= "main"
}
resource "google_compute_firewall" "tcp_firewall" {
 name			        = "tcp"
 network		        = "main"

 allow {
   protocol		        = "tcp"
   ports		        = ["8080", "3000-3001"]
  }

 source_ranges			= ["0.0.0.0/0"]
}
resource "google_compute_firewall" "http_firewall" {
 name                           = "http-firewall"
 network                        = "main"
 description			= "Allow HTTP traffic"
 target_tags			= ["http-server"]

 allow {
   protocol                     = "tcp"
   ports                        = ["80"]
  }

 source_ranges			= ["0.0.0.0/0"]
}
resource "google_compute_firewall" "ssh_firewall" {
 name                           = "ssh"
 network                        = "main"
 priority			= 65534
 allow {
   protocol                     = "tcp"
   ports                        = ["22"]
  }

 source_ranges			= ["0.0.0.0/0"]
} 
resource "google_compute_instance_template" "tf-instance-template" {
 name			        = "tf-instance-template"
 description			= "Instance Template with existing boot disk image"

 machine_type			= "e2-medium"

 disk {
   source_image			= "image-todo"
 }

 network_interface {
   network			= "main"
   subnetwork			= "main-subnet"
   
   access_config {}
 }
 tags				= ["http-server"]
 metadata_startup_script	= <<-SCRIPT echo "NEWNEWNEW" && cd /home/milan_veljkovic0097/cloud_student_internship/frontend && cat > .env.development <<EOF REACT_APP_API_URL=http://$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip):3001/api EOF && docker-compose build && docker-compose up   SCRIPT
}
resource "google_compute_instance_from_template" "instance-tf" {
 depends_on			= [google_compute_instance_template.tf-instance-template]
 name				= "tf-instance"
 zone				= "us-central1-a"
 source_instance_template	= google_compute_instance_template.tf-instance-template.self_link
}
resource "google_compute_instance_group_manager" "todo-instance-group" {
  name				= "todo-instance-group"
  base_instance_name		= "todo-app-1"
  zone				= "us-central1-a"
  target_size			= 1
  named_port {
   name				= "http"
   port				= "3000"
  }
  version {
    instance_template		= google_compute_instance_template.tf-instance-template.self_link
  }
}
resource "google_compute_health_check" "health-check-lb" {
 name				= "health-check-lb"
 check_interval_sec		= 30
 healthy_threshold		= 2
 http_health_check {
  port				= 3000
  request_path			= "/"
 }
 timeout_sec			= 5
 unhealthy_threshold		= 2
}
resource "google_compute_backend_service" "lb-backend-service" {
  name				= "lb-backend-service"
  health_checks			= [google_compute_health_check.health-check-lb.id]
  port_name			= "http"
  protocol			= "HTTP"
  enable_cdn			= true
  timeout_sec			= 30
  load_balancing_scheme		= "EXTERNAL"
  backend{
    group			= google_compute_instance_group_manager.todo-instance-group.instance_group
  }
}
resource "google_compute_global_address" "lb-address" {
  name				= "lb-address"
  ip_version			= "IPV4"
}

resource "google_compute_global_forwarding_rule" "load-balancer-tf" {
  name				= "load-balancer-tf"
  ip_protocol			= "TCP"
  port_range			= 80
  load_balancing_scheme		= "EXTERNAL_MANAGED"
  target			= google_compute_target_http_proxy.lb-proxy.self_link
  ip_address			= google_compute_global_address.lb-address.id
}

resource "google_compute_url_map" "url-map" {
  name				= "url-map"
  default_service		= google_compute_backend_service.lb-backend-service.id

}

resource "google_compute_target_http_proxy" "lb-proxy" {
  name				= "lb-proxy"
  url_map			= google_compute_url_map.url-map.id
}

