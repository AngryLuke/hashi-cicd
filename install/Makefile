PLATFORM="x86_64"
OS="linux"

define usage
	@echo "Usage: make [all|install|configure|tkrun|clean] [TFEORG=<TFC_ORG> [TFEUSER=<YOUR_TFC_USER>] [SECRETSFILE=<YOUR_SECRETS_FILE>] [TFEVALUESFILE=<YOUR_TFE_VALUES_FILE>]]"
endef


.PHONY: all
all: install configure

install:
	./00-install.sh all

configure:
ifdef TFEORG
ifdef TFEUSER
ifdef SECRETSFILE
ifdef TFEVALUESFILE
	./01-deploy.sh $(TFEORG) $(TFEUSER) $(SECRETSFILE) $(TFEVALUESFILE)
else
	@echo "There is no Terraform username defined\n"
	$(call usage)
endif
else
	@echo "There is no Terraform organization in the parameters\n"
	$(call usage)
endif
else
	@echo "No secrets.json provided in the parameters\n"
	$(call usage)
endif
else
	@echo "No tfe_values.json provided in the parameters\n"
	$(call usage)
endif


jenkins:
	./00-install.sh jenkins

tekton:
	./00-install.sh tekton

tkrun:
ifdef TFEWORK
	kubectl apply -f ../tekton
	tkn pipeline start -p tfc-organization="$(TFEORG)" -p tfc-workspace="$(TFEWORK)" -s tekton-sa vault-tfc-pipeline
	tkn tr logs -f -L
else
	@echo "There is no Terraform workspace in the parameters\n"
	$(call usage)
endif

clean:
	./02-clean.sh

help:
	$(call usage)
