# Automated Pipeline

This automated pipeline uses terraform, python and SQL and is automatically deployed from the command line to initiate the whole pipeline and its required services.

## Installataion

In the terraform.tfvars file, you will need to manually enter some variables to ensure the pipeline runs in your environment.

You will also need to change line 17 in the main.tf file to the same bucket you have specified in the terraform.tfvars file.

You will also need to create service account key.json and ensure it site one folder above this project.

## Usage
cd to the terraform folder using cd/terraform

```terrafrorm 
terraform init

terraform plan -var-file=terraform.tfvars

terraform apply -var-file=terraform.tfvars -auto-approve
```
## License
[MIT](https://choosealicense.com/licenses/mit/)
