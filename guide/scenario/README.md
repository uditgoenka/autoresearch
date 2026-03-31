# Scenario Guides

Real-world, end-to-end walkthroughs of `/autoresearch:scenario` applied to specific domains and use cases. Each guide includes the command config, example situations generated across the 12 exploration dimensions, chain patterns, and domain-specific tips.

For the command reference, see [autoresearch-scenario.md](../autoresearch-scenario.md).

---

## Guides

| # | Guide | Domain | Depth | Key Dimensions |
|---|-------|--------|-------|----------------|
| 1 | [Real-Time Chat Messaging](real-time-chat-messaging.md) | software | deep | concurrent, recovery, temporal |
| 2 | [Multi-Tenant SaaS Onboarding](multi-tenant-saas-onboarding.md) | software | standard | permission, data variation, state transition |
| 3 | [CI/CD Pipeline Deployment](cicd-pipeline-deployment.md) | software | deep | recovery, error, state transition |
| 4 | [Healthcare Appointment Scheduling](healthcare-appointment-scheduling.md) | business | deep | temporal, permission, concurrent |
| 5 | [Social Media Content Moderation](social-media-content-moderation.md) | product | standard | edge case, abuse, scale |
| 6 | [IoT Firmware Updates](iot-firmware-updates.md) | software | deep | recovery, error, scale |
| 7 | [Document Collaboration](document-collaboration.md) | software | deep | concurrent, state transition, permission |
| 8 | [Cross-Border Wire Transfers](cross-border-wire-transfers.md) | security | deep | abuse, permission, integration |
| 9 | [Search Autocomplete](search-autocomplete.md) | software | standard | edge case, scale, data variation |
| 10 | [Mobile Push Notifications](mobile-push-notifications.md) | product | standard | scale, temporal, data variation |
| 11 | [Adversarial Architecture Decisions](adversarial-architecture-decisions.md) | software | deep | integration, state transition, edge case |

---

## How to Use These Guides

Each guide is a self-contained example you can adapt to your own project:

1. **Read the scenario** — understand what's being explored and why
2. **Copy the command** — adjust scope and iterations for your codebase
3. **Review the example situations** — see what autoresearch:scenario surfaces
4. **Follow the chain** — each guide suggests next steps (debug, fix, security, ship, learn)

## Quick Picks

| I'm building... | Start with |
|-----------------|------------|
| A real-time feature (chat, collab, live updates) | [Real-Time Chat](real-time-chat-messaging.md) or [Document Collaboration](document-collaboration.md) |
| A multi-tenant platform | [SaaS Onboarding](multi-tenant-saas-onboarding.md) |
| DevOps / deployment automation | [CI/CD Pipeline](cicd-pipeline-deployment.md) |
| A regulated system (health, finance) | [Healthcare Scheduling](healthcare-appointment-scheduling.md) or [Wire Transfers](cross-border-wire-transfers.md) |
| A consumer product with UGC | [Content Moderation](social-media-content-moderation.md) |
| Hardware / embedded systems | [IoT Firmware Updates](iot-firmware-updates.md) |
| A search feature | [Search Autocomplete](search-autocomplete.md) |
| Mobile notifications | [Push Notifications](mobile-push-notifications.md) |
| Making architecture or design decisions | [Adversarial Architecture Decisions](adversarial-architecture-decisions.md) |

---

<div align="center">

**[Guide Index](../README.md)** | **[Scenario Command Reference](../autoresearch-scenario.md)** | **[Chains & Combinations](../chains-and-combinations.md)**

</div>
