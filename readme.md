# CP4D Non-OLM GitOps Installation

This project implements automated GitOps installation and management for IBM Cloud Pak for Data/Software Hub and related cartridges through the Non-OLM method. It leverages ArgoCD and Kustomize for resource layering and declarative configuration, supporting extension and secondary development.

## Features
- Automated the Non-OLM installation method for CP4D/Software Hub and Cartrigdes managed by ArgoCD for continuous integration and delivery. 
- Developed based on [IBMSoftwareHub/charts/tree/5.2.0](https://github.ibm.com/IBMSoftwareHub/charts/tree/5.2.0) and restructure as layers (cluster scoped, namespace scoped, cartridge) for clean management.
- Pluggable enable/disable for any cartridge.
- Parameterisation and automatic variable substitution, making it easy to adapt to different environments and team collaboration

#### Newly Added Cartridges
- OpenPages
- Cognos Analytics
- watsonx.ai

#### Newly Added Dependencies
|Dependency|Version|Related Cartridge|
|---|---|---|
|cert-manager-operator (for Red Hat OpenShift)|1.17.0|Software Hub|
|ibm-rabbitmq-operator|1.0.50|OpenPages|
|ibm-db2uoperator|7.3.0|OpenPages|
|ibm-db2aaservice|5.2.0|OpenPages|
|ibm-ccs|11.0.0|Cognos Analytics, watsonx.ai|
|ibm-opensearch-operator|1.1.2494|Cognos Analytics, watsonx.ai|
|ibm-datarefinery|11.0.0|watsonx.ai|
|ibm-wml-cpd|11.0.0|watsonx.ai|
|ibm-wsl-runtimes|11.0.0|watsonx.ai|
|ibm-wsl|11.0.0|watsonx.ai|
|ibm-watsonx-ai-ifm|11.0.0|watsonx.ai|

## Directory Structure (Top Level)
```
.
├── 0-bootstrap/          # Bootstrap scripts and initialisation resources
├── 1-cluster-scope/      # Cluster-scoped resources for Software Hub
├── 2-namespace-scope/    # Namespace-scoped operators for Software Hub
├── 3-cartridge/          # Cartridges and their dependencies
├── 9-post-installation/  # Post installation po
├── cp4d-gitops.yaml      # Top-level ArgoCD Application
├── kustomization.yaml    # Root Kustomize aggregation file
├── repos/                # Helm chart packages
└── values.yaml           # Central parameter management file
```

## Usage

1. Click [Use this template](https://github.com/new?template_name=non-olm-cp4d-gitops&template_owner=gitops-cp4d) at the right top of this page to create your own repository, then clone it to your local and enter the project directory.

2. Edit the root `values.yaml` to customize namespaces, storage classes, and other parameters.  
**Please make sure to update the value of `argoSourceRepoURL` to point to the repository you just created**. ArgoCD will treat this repository as the source of truth for synchronisation.  
If you are using a [Techzone environment](https://techzone.ibm.com/collection/tech-zone-certified-base-images/journey-base-open-shift), other parameters can be left as default.

3. Edit the root `kustomization.yaml` as needed. You can enable or disable any cartridge module by commenting or uncommenting its resource. It is recommended to disable(comment) all cartridges at first. Only enable (uncomment) the 3-cartridge resources in `kustomization.yaml` after Software Hub installation is completed and both `1-cluster-scope/` and `2-namespace-scope/` resources have been successfully reconciled.


4. Run the bootstrap script (only required for the first time setup):
    ```
    ./0-bootstrap/bootstrap.sh
    ```
    This script will:
    - Check the OpenShift environment and prerequisites
    - Process and substitute all parameters in manifests
    - Push the updated manifests to the remote repository
    - Apply bootstrap manifests (such as namespaces, RBAC for Argo, health-checks)
    - Create the Kubernetes secret for your IBM Container Entitlement Key
    - Apply the top-level ArgoCD Application (`cp4d-gitops.yaml`)
    - Output ArgoCD dashboard login information

5. After the basic Software Hub Platform (`1-cluster-scope/` and `2-namespace-scope/` resouces) installation completes, the credentials and URL can be retrieved by:
    - Retrieving from Argo CD dashboard:
    Open the `post-installation-info` Deployment under the `post-installation` Application and view its logs.
    - Retrieving with `oc` command: 
    please replace `<instanceNS>` with the same values from values.yaml
        ```
        oc logs deployment/post-installation-info -n <instanceNS>
        ```
        or
        ```
        oc get route cpd -n <instanceNS> -o jsonpath='{.spec.host}'
        oc get secret platform-auth-idp-credentials -n <instanceNS> -o jsonpath='{.data.admin_username}' | base64 --decode && echo
        oc get secret platform-auth-idp-credentials -n <instanceNS> -o jsonpath='{.data.admin_password}' | base64 --decode && echo
        ```

6. Any further changes (including enabling/disabling cartridges by commenting/uncommenting their resources in `kustomization.yaml` after Software Hub installation is completed) should be committed and pushed to your Git repository directly. ArgoCD will automatically detect and synchronise all changes from Git. Installation will likely take over 1 hours or more depending on the number of services enabled

7. To enable watsonx.ai, please make sure you have done the prerequisite for watsonx.ai https://www.ibm.com/docs/en/software-hub/5.2.x?topic=cluster-installing-prerequisite-software, and uncommenting the resource `3-cartridge/watsonx-ai` in `kustomization.yaml` to start the synchronisation of watsonx.ai resources.


## Development Guide

- You are welcome to contribute more dependencies or cartridges. Please follow the existing layered directory structure for expansion.
- New dependencies should be placed in `3-cartridge/<cartridge-name>/` with a dedicated `kustomization.yaml` for modular aggregation.
- It is recommended to manage all parameters centrally in `values.yaml`.
- For development and extension, please refer to the technical specification: [Technical Specification: Non-OLM Install Method](https://github.ibm.com/PrivateCloud-analytics/CPD-TechSpec/blob/master/non-OLM-install-method.md)
