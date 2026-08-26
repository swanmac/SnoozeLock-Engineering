# SnoozeLock Architecture Overview

SnoozeLock is structured as a collection of native iOS features coordinated through shared application state and reusable SwiftUI components.

The architecture is designed around one central requirement: alarm workflows must remain predictable while coordinating time-sensitive system behavior, user challenges, native device capabilities, and premium feature access.

## Core Areas

### Alarm Management

Alarm scheduling and lifecycle behavior are coordinated through AlarmKit.

The alarm layer is responsible for:

- Creating and scheduling alarms
- Managing repeat schedules
- Supporting snooze behavior
- Coordinating alarm state with application state
- Handling alarm-related actions and dismissal workflows

Alarm functionality is kept separate from individual wake challenges so that challenge behavior can evolve without requiring changes to the underlying alarm scheduling system.

### Wake Challenge System

SnoozeLock supports multiple challenge types that can be required before an alarm is dismissed.

Current challenge types include:

- Math
- Typing
- Step Count
- Barcode Scan

Each challenge owns its own validation and completion behavior while participating in a shared challenge workflow.

This allows challenges to be added or modified without tightly coupling them to the alarm-management layer.

### Challenge Stacking

Multiple challenges can be configured as a sequential workflow.

The application tracks:

- Current challenge
- Completion state
- Remaining challenges
- Final alarm-dismissal eligibility

The alarm is dismissed only after the configured challenge sequence has been completed.

### Native Device Integrations

Device-specific functionality is isolated into dedicated feature areas.

#### CoreMotion

CoreMotion supports the Step Count challenge by monitoring user movement and reporting progress toward the required number of steps.

#### Camera / Barcode Scanning

The Barcode Scan challenge uses the device camera to verify that the user has physically reached a predetermined location or object before the challenge is considered complete.

#### AlarmKit

AlarmKit provides the system-level alarm functionality required for reliable alarm scheduling and interaction.

Keeping these integrations separate from presentation logic helps make the application easier to test, maintain, and extend.

### Application State

SwiftUI views react to shared application state rather than directly managing system integrations.

State includes information such as:

- Alarm configuration
- Active challenge
- Challenge completion
- Snooze configuration
- Premium feature availability
- Alarm lifecycle state

This separation reduces coupling between interface components and device services.

### Premium Feature Access

SnoozeLock uses StoreKit 2 for its one-time Pro unlock.

Premium functionality includes features such as:

- Step Count challenges
- Barcode Scan challenges
- Mission Recall
- Challenge Stacking

Purchase state is kept separate from the individual features so that the application can consistently determine whether a premium workflow should be available.

### Testing Strategy

Testing includes both simulator and physical-device validation.

Physical-device testing is especially important for:

- Alarm behavior
- Camera access and barcode scanning
- Motion tracking
- Permission workflows
- StoreKit purchases and restoration
- Background and device-specific behavior

Features that rely on native hardware are validated on real iPhone hardware before production release.

## Design Goals

The architecture is intended to keep SnoozeLock:

- Modular
- State-driven
- Testable
- Maintainable
- Extensible as additional wake challenges are introduced

The goal is to keep system-level alarm behavior, device integrations, application state, and SwiftUI presentation responsibilities clearly separated while maintaining a simple experience for the user.
