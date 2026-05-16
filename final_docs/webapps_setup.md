"""
FILE: webapps_setup.md
TOPIC: Webapps Setup
SUMMARY: This document provides technical details on Webapps Setup.
It covers: **URL:** https://wearables.developer.meta.com/docs/develop/webapps/setup/ --- Build for Wearables API reference Support...
Use this file for implementing features related to this topic.
"""

# Setup

**URL:** https://wearables.developer.meta.com/docs/develop/webapps/setup/

---

Build for Wearables
API reference
Support
Login
Register
Web Apps
Setup
Build
Test
Troubleshoot
Setup
Updated: May 26, 2026
Overview
Setting up to build Web Apps for Meta Ray-Ban Display glasses (MRBD) takes three steps:
Check your hardware. Confirm your glasses, paired phone, and (optionally) Meta Neural Band meet the minimum requirements.
Check your Meta AI app and enable Developer Mode. Verify the app version on your phone, then put the app into Developer Mode so it can load Web Apps onto the glasses.
Prepare to host your Web App. Pick a hosting platform that serves your app over HTTPS so the glasses can load it.
Requirements
Hardware
Web Apps are supported only on Meta Ray-Ban Display (MRBD) glasses. Meta Neural Band is optional, though recommended for an optimal experience.
Software
For the best experience, always update your glasses and Meta Neural Band with the latest software updates.
Glasses
The minimum glasses software version is v125+. To verify the glasses software version:
In the Meta AI app, tap Devices (the glasses icon), and select your device.
Tap the gear icon to open Device settings.
Tap General > About > Release Version.
Check for glasses software updates if your version is below v125.
Meta AI App
The minimum Meta AI app version is v272+. To verify Meta AI app version:
Open the Meta AI app.
Tap Settings > App Info.
Note the App version number. If it’s older than v272, update the Meta AI app from the App Store (iOS) or Play Store (Android).
Enabling Developer Mode in the Meta AI app
Developer Mode in the Meta AI app unlocks the menu options used to load and reload Web Apps on MRBD.
Open the Meta AI app on your paired iOS or Android device.
Select Settings > App Info, and then tap the App version number five times to display a pop-up that enables Developer Mode.
Click Enable to confirm.
Note: Developer Mode persists across sessions, so you don’t need to re-enable it each time you open the Meta AI app.
Hosting your Web App
Your Web App must be hosted on a publicly accessible HTTPS URL so MRBD can load it.
Common options include: Replit, Lovable, Vercel, GitHub Pages, Netlify, Cloudflare Pages, or any static site host that serves over HTTPS. You can also host from your own server, as long as it serves the app over HTTPS with a valid TLS certificate.
While it’s possible to point MRBD at any website, most sites are not configured to work well within the platform’s display and input constraints. See Building Web Apps for the design and runtime constraints to keep in mind.
Note:
HTTP-only URLs are not supported. The glasses runtime requires HTTPS for every Web App URL it loads.
Our AI Coding plugin⁠ includes skills that will help you deploy to Vercel.
ON THIS PAGE
Overview
Requirements
Hardware
Software
Enabling Developer Mode in the Meta AI app
Hosting your Web App
Build with Meta
Social Technologies
Meta Horizon
AI
Worlds
Wearables
About us
Careers
Research
Products
Support and legal
Wearables Developer Terms
Acceptable Use Policy
Legal
Privacy
English (US)
© 2026 Meta