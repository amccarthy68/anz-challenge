# This Terraform script has been designed to deploy all services required to deploy and run a simple pipeline
## that streams pubsub messages to bigquery via a templated dataflow job, 
### then turns on composerif not already enabled and adds dags for scheduled reporting.



#Initialise Terraform Backend in GCP using service account JsonKeys
provider "google" {
  credentials = "${file("../../account.json")}" # key sits outside project forlder, replace with your own service account key to run
  project     = "${var.project}"
  region      = "${var.region}"
}

terraform {

  backend "gcs" {
    bucket = "martin-bt-test" #replace with any bucket to run in ANZ environment
    prefix = "terraform/"

  }
}

# creates the pubsub topic
resource "google_pubsub_topic" "subscription-data" {
  name = "subscription-data"

  project = "${var.project}"

  message_storage_policy {
    allowed_persistence_regions = [
      "${var.region}"
    ]
  }
}

# creates the BQ dataset and Table
resource "google_bigquery_dataset" "mobile_subscriptions" {
  dataset_id    = "mobile_subscriptions"
  friendly_name = "mobile_subscriptions"
  description   = "dataset containing all moobile subscriber data"
  location      = "US"
  project       = "${var.project}"
}

resource "google_bigquery_table" "subscriber_data" {
  project    = "${var.project}"
  dataset_id = google_bigquery_dataset.mobile_subscriptions.dataset_id
  table_id   = "subscriber_data"
  schema     = (file("../schemas/subscriber_data.json"))

}

#creates dataflow job to load messages to BQ table

resource "google_dataflow_job" "stream-subscriber-data" {

  name              = "stream-subscriber-data"
  on_delete         = "cancel"
  zone              = "${var.zone}"
  max_workers       = 3
  template_gcs_path = "gs://dataflow-templates/latest/PubSub_to_BigQuery"
  temp_gcs_location = "${var.bucket}"
  parameters = {
    inputTopic      = "projects/${var.project}/topics/subscription-data"
    outputTableSpec = "${var.project}:mobile_subscriptions.subscriber_data"
  }
}

resource "google_storage_bucket" "bucket" {
  name = "${var.function_bucket}"
}

resource "google_storage_bucket_object" "archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.bucket.name
  source = "../cloud_function/function.zip"
}

resource "google_cloudfunctions_function" "extract_data" {
  name                  = "extract_data"
  description           = "extracts the reports to bucket"
  runtime               = "python37"
  project               = "${var.project}"
  region = "${var.region}"
  available_memory_mb   = 1024
  trigger_http          = true
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  timeout               = 540
  service_account_email = "${var.service_account}"
  environment_variables = {
    bucket = "${var.bucket_short}"
  }
}
# create the trigger to run reports at midnight
resource "google_cloud_scheduler_job" "trigger-reports" {
  name             = "run-cloud-function"
  description      = "run the cloud function at midnight"
  region = "australia-southeast1"
  schedule         = "0 0 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "get"
    uri         = "https://us-central1-${var.project}.cloudfunctions.net/extract_data"

    oidc_token {
      service_account_email = "${var.service_account}"
    }
  }
}