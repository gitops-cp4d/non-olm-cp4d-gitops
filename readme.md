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
- cert-manager for Openshift by RH
- ccs for CP4D
- RabbitMQ
- Db2u
- Db2aaservices

#### Newly Added Cartridges

- OpenPages
- Cognos Analytics

## Usage

1. Click [Use this template](https://github.com/new?template_name=non-olm-cp4d-gitops&template_owner=gitops-cp4d) at the right top of this page to create your own repository, then clone it to your local and enter the project directory.

2. Edit the root `values.yaml` to customize namespaces, storage classes, and other parameters.  
If you are using a [Techzone environment](https://techzone.ibm.com/collection/tech-zone-certified-base-images/journey-base-open-shift), most parameters can be left as default.

3. Edit the root `kustomization.yaml` as needed. You can enable or disable any cartridge module by commenting or uncommenting its resource.

4. Run the bootstrap script:
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

Remaining resource sync and lifecycle management is fully automated by ArgoCD and can be managed through its UI.

## Development Guide

- You are welcome to contribute more dependencies or cartridges. Please follow the existing layered directory structure for expansion.
- New dependencies should be placed in `3-cartridge/<cartridge-name>/` with a dedicated `kustomization.yaml` for modular aggregation.
- It is recommended to manage all parameters centrally in `values.yaml`.
- For development and extension, please refer to the technical specification: [Technical Specification: Non-OLM Install Method](https://github.ibm.com/PrivateCloud-analytics/CPD-TechSpec/blob/master/non-OLM-install-method.md)
