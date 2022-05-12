provider "google" {
    credentials = file("service-account.json")
    project     = "strange-retina-346405"
    region      = "us-west1"
    zone        = "us-west1-c"
}