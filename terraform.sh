#!/bin/bash
docker run -v ~/.aws:/root/.aws:ro -e AWS_DEFAULT_REGION=us-east-2  -e AWS_PROFILE=dutchsec -v $(pwd):/work -i -t hashicorp/terraform -chdir=/work $@
