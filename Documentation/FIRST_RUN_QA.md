<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# First Run QA

The source implements a four-step onboarding sheet, skip/back/continue actions,
a real Full Disk Access probe, optional notification request, launch-location
diagnostics, security-profile selection and a summary. It can be reopened from
Settings via the existing notification route. Permissions are explained before
they are requested and the app remains usable with reduced coverage.

Verified from the 0.9.0 release bundle: launch, Smart Care idle state, obvious
primary “Start Smart Care Scan” action, module sidebar, dark/light appearance
and isolated temporary-store behavior. The public quarantined copy reached the
real macOS block before app launch, as expected.

Not yet verified on a clean standard account: exact onboarding persistence,
accept/refuse/withdraw permission combinations, VoiceOver announcement order,
keyboard focus order, logout/reboot persistence and time-to-first-result on a
neutral realistic fixture. These require the single human-isolated session
defined in `USER_JOURNEY_QA.md`; no result is inferred from unit tests.
