# Table of contents

* [Simeon Overview](README.md)
* [How To](how-to.md)
* [Approvals](how-to-require-approvals.md)
* [Automated Microsoft 365 Configuration Types](automated-microsoft-365-configuration-types.md)

# Simeon Overview

Each Microsoft 365 tenant managed by Simeon will have:

* A Git **repository** in Azure where tenant configurations are stored as code
* An **Export Pipeline** in Azure that exports and stores as code all changes made to a tenant's configurations in the Microsoft Portal
* A **Deploy Pipeline** in Azure that publishes the tenant configurations from the repository to a tenant

Configuration Repositories are layered to create the desired state of configurations that are being deployed to a tenant at any given time. Each subsequent layer after the **Baseline** takes priority over the layer before it. Simeon supports three layers depending on each MSP's desired level of customizations.   
  
The three layers include:

* The built-in **Simeon Baseline** 
  * A set of best practice configurations developed by Simeon \(e.g. requiring multi-factor authentication and packages for common apps like 7-Zip and Google Chrome\)
* Your own **MSP Specific Baseline**
  * Configurations an MSP may want to apply to all or many of their tenants \(e.g. custom branding\) 
* **Tenant Specific Configurations**
  * Configurations that are specific to an individual tenant \(e.g. specialized software, printer deployment, and drive mapping scripts\)
