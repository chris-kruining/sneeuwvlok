# Identity Clan service

Foundational identity provider service. The initial driver is `zitadel`; it configures Zitadel, exports the provider origin for consumers, and publishes the identity gateway service.

Instance settings own the Zitadel organization, project, user, role, application, action, and trigger configuration. Consumer applications can be declared directly in the identity settings or selected from explicit exported identity applications.

When an application has an `origin` and `callbackPath`, the service derives the redirect URI from those values. The Zitadel driver also claims the `zitadel` PostgreSQL database through the persistence interface.