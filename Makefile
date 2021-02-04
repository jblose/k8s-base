UNAME_S              := $(shell uname -s)
TARGET_ENV           ?= $(shell basename `pwd`)

TARGET_AZ_SUB_NAME   ?= <Azure Subcription>
BACKEND_AZ_RGP       ?= <Azure Backend RGP>
BACKEND_AZ_SA_NAME   ?= <Azure Backend Storage Account Name>
BACKEND_AZ_CONTAINER ?= tf-state
BACKEND_AZ_STATE_KEY ?= $(TARGET_ENV)/terraform.state

# Check the system keychain for stored encryption pass
ifeq ($(UNAME_S),Linux)
endif
ifeq ($(UNAME_S),Darwin)
	ENCRYPTION_PASS ?= $(shell security find-generic-password -a "${USER}" -s "$(KEYCHAIN_PREFIX)/$(TARGET_ENV)" -w)
endif
# Check keepass for stored encryption pass if not available in OS keychain
ifeq ($(ENCRYPTION_PASS),)
	ifneq ($(shell which keepassxc-cli),)
		ENCRYPTION_PASS := $(shell keepassxc-cli show "$(KEEPASS_DB_PATH)" "$(KEEPASS_ENTRY)" -s -a password)
	endif
endif

.PHONY: test all clean az-login-sp az-login az-account-set tf-init encrypt-secrets decrypt-secrets

dep:
	terraform get -update

az-login:
	@az login

az-account-set: az-login
	@wait
	@az account set -s '$(TARGET_AZ_SUB_NAME)'

tf-init: dep
	terraform init -backend-config="resource_group_name=$(BACKEND_AZ_RGP)" -backend-config="storage_account_name=$(BACKEND_AZ_SA_NAME)" -backend-config="container_name=$(BACKEND_AZ_CONTAINER)"  -backend-config="key=$(BACKEND_AZ_STATE_KEY)"

tf-plan: tf-init dep
	terraform plan -out "out.plan"

ifneq ($(ENCRYPTION_PASS),)
decrypt-secrets:
	@openssl enc -d -aes-256-cbc -pass "pass:${ENCRYPTION_PASS}" -in "secrets.tfvars.enc" -out "secrets.tfvars"

encrypt-secrets:
	@openssl enc -aes-256-cbc -pass "pass:${ENCRYPTION_PASS}" -in "secrets.tfvars" -out "secrets.tfvars.enc"

else
decrypt-secrets:
	@echo "ENCRYPTION_PASS is not set."

encrypt_secrets:
	@echo "ENCRYPTION_PASS is not set."

endif

