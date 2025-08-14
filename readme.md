# CP4D Non-OLM GitOps Installation

This project implements automated GitOps installation and management for IBM Cloud Pak for Data and related cartridges, using the Non-OLM method. It leverages ArgoCD and Kustomize for resource layering and declarative configuration, supporting extension and secondary development.

## Directory Structure (Top Level)
```
.
├── 0-bootstrap/          # Bootstrap scripts and initialisation resources
├── 1-cluster-scope/      # Cluster-scoped resources
├── 2-namespace-scope/    # Namespace-scoped operators
├── 3-cartridge/          # CP4D Cartridges and their dependencies
├── cp4d-gitops.yaml      # Top-level ArgoCD Application
├── kustomization.yaml    # Root Kustomize aggregation file
├── repos/                # Helm chart packages
└── values.yaml           # Central parameter management file
```

## Solution Overview

This project aims to automated the Non-OLM installation method for CP4D and Cartrigdes and integrated with ArgoCD for continuous integration and delivery. It is developed based on [IBMSoftwareHub/charts/tree/5.2.0](https://github.ibm.com/IBMSoftwareHub/charts/tree/5.2.0), and utilizes Kustomize for resource layering and parameterization.

#### Key Features:
- Layered resource grouping (bootstrap, foundation, cluster, namespace, cartridge) for clean management
- Pluggable enable/disable for any cartridge
- Parameterisation and automatic variable substitution, making it easy to adapt to different environments and team collaboration
- Supports custom extension and secondary development

#### Newly Added Dependencies
- cert-manager-operator(for Red Hat OpenShift)
- ibm-ccs
- ibm-opensearch-operator
- ibm-rabbitmq-operator
- ibm-db2uoperator
- ibm-db2aaservice

#### Newly Added Cartridges

- OpenPages
- Cognos Analytics

## Usage

1. Click [Use this template](https://github.com/new?template_name=non-olm-cp4d-gitops&template_owner=gitops-cp4d) at the right top of this page to create your own repository, then clone it to your local and enter the project directory.

2. Edit the root `values.yaml` to customize namespaces, storage classes, and other parameters.  
Please make sure to update the value of `argoSourceRepoURL` to point to **your own created repository**. ArgoCD will treat this repository as the source of truth for synchronisation.  
If you are using a [Techzone environment](https://techzone.ibm.com/collection/tech-zone-certified-base-images/journey-base-open-shift), other parameters can be left as default.

3. Edit the root `kustomization.yaml` as needed. You can enable or disable any cartridge module by commenting or uncommenting its resource. It is recommended to disable all cartridges at first. Only enable (uncomment) the 3-cartridge resources in `kustomization.yaml` after Software Hub installation is completed and both `1-cluster-scope/` and `2-namespace-scope/` resources have been successfully reconciled.


4. Run the bootstrap script (only required for the first time setup):
    ```
    ./0-bootstrap/bootstrap.sh
    ```
    This script will:
    - Check the OpenShift environment and prerequisites
    - Update the Git repository address for Argo application manifest
    - Process and substitute all parameters in manifests
    - Push the updated manifests to the remote repository
    - Apply bootstrap manifests (such as namespaces, RBAC for Argo, health-checks)
    - Create the Kubernetes secret for your IBM Container Entitlement Key
    - Apply the top-level ArgoCD Application (`cp4d-gitops.yaml`)
    - Output ArgoCD dashboard login information

5. Any further changes (including enabling/disabling cartridges by commenting/uncommenting their resources in `kustomization.yaml` after Software Hub installation is completed) should be committed and pushed to your Git repository directly. ArgoCD will automatically detect and synchronize all changes from Git.

6. Installation will likely take over 1 hours or more depending on the number of services enabled

7. To access the platform the following commands can be used to get the route, username and password.
    ```
    oc get route cpd -n <instance-namespace> -o jsonpath='{.spec.host}'
    oc get secret platform-auth-idp-credentials -n <instance-namespace> -o jsonpath='{.data.admin_username}' | base64 --decode && echo
    oc get secret platform-auth-idp-credentials -n <instance-namespace> -o jsonpath='{.data.admin_password}' | base64 --decode && echo
    ```
## Development Guide

- You are welcome to contribute more dependencies or cartridges. Please follow the existing layered directory structure for expansion.
- New dependencies should be placed in `3-cartridge/<cartridge-name>/` with a dedicated `kustomization.yaml` for modular aggregation.
- It is recommended to manage all parameters centrally in `values.yaml`.
- For development and extension, please refer to the technical specification: [Technical Specification: Non-OLM Install Method](https://github.ibm.com/PrivateCloud-analytics/CPD-TechSpec/blob/master/non-OLM-install-method.md)
