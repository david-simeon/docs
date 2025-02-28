### Where is it hosted

The Simeon software runs securely in your own Azure DevOps environment, tied directly to your own Azure tenant and subscription.

Because Simeon runs in your own Azure DevOps environment, you are in complete control of the security. You can harden access to your Azure DevOps environment as much as you like.

Our Web Admin user interface connects directly to your Azure DevOps environment and none of your data ever passes through our servers.

### Configuring the tenant

Simeon can use either delegated authentication or a service account to interact with your tenants. 

When using delegated authentication, Simeon will securely store an encrypted refresh token in your Azure DevOps environment and the software will run as the account used to install the tenant. This works in the same way as Microsoft Flow does when authenticating with connectors.

When using a service account, Simeon creates a service account with a randomly generated 15 character password that is immediately stored in a secret variable in Azure DevOps and then discarded. This password cannot be viewed by anyone. Only the Sync job can use this password to connect to and configure your tenant.

Before making any changes to your tenant, Azure DevOps will wait for you to explicitly approve the changes to be made.

### Support 

Simeon support can be granted read-only or contributor access to your Azure DevOps environment to help troubleshoot any issues. Simeon support will never make changes to your tenants and can be explicitly denied permissioned to do so.

### The software

We digitally sign our software and the processes that run in Azure DevOps confirm the integrity of the software before interacting with your tenant. 
