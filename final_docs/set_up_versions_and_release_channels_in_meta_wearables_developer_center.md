"""
FILE: set_up_versions_and_release_channels_in_meta_wearables_developer_center.md
TOPIC: Set Up Versions And Release Channels In Meta Wearables Developer Center
SUMMARY: This document provides technical details on Set Up Versions And Release Channels In Meta Wearables Developer Center.
It covers: Set up versions and release channels in Meta Wearables Developer Center Effectively manage how you distribute and test Meta integrations by setting up versions and release channels in the Meta Wearables Developer Center. This guide walks you through ...
Use this file for implementing features related to this topic.
"""

Set up versions and release channels in Meta Wearables Developer Center

Effectively manage how you distribute and test Meta integrations by setting up versions and release channels in the Meta Wearables Developer Center. This guide walks you through best practices and step-by-step instructions to help you roll out updates, gather meaningful feedback, test features safely, and maintain integration quality.

## Understand versions

Wearables Developer Center uses a versioning system that helps track changes and maintain stability across your integrations. Each version details product specifics, including the name, icon, and any edits to permission requests or app configuration.

After you add and save these details you can find them by going to **Distribute > Version details > Project data**.


When you change any of these details, you need to create a new version of the integration so you can distribute it to testers on a release channel.

When selecting the version to use, the type of change you are making determines the category you should choose:

- **Major (e.g., 2.3.4 to 3.0.0):** Choose this for significant changes or API revisions that are not guaranteed to maintain compatibility with previous versions. For example, select a major version if you change core app functionality in a way that breaks existing features.
- **Minor (e.g., 2.3.4 to 2.4.0):** Select a minor version when introducing new features while still maintaining backwards compatibility. For example, if you add a new button or feature.
- **Patch (e.g., 2.3.4 to 2.3.5):** Use a patch version for fixing bugs or delivering minor improvements that do not break compatibility, such as correcting a typo or a small bug fix.

## Create versions

To create a new version of your integration:

1. Log in to the [Meta Wearables Developer Center](https://wearables.developer.meta.com/).
2. Select your project from the dashboard.
3. Go to the **Distribute** menu and choose **Versions**.
4. Click **+ New version**.
5. Select your version type (**Major, Minor, or Patch**).
6. Click **Create version**.

## About release channels

Release channels let you control distribution of your versions. By creating and assigning versions to specific channels, you determine which user groups access each version. Each channel supports only one version at a time, but you can attach the same version to multiple channels if needed.
