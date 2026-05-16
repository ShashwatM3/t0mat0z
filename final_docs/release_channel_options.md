"""
FILE: release_channel_options.md
TOPIC: Release Channel Options
SUMMARY: This document provides technical details on Release Channel Options.
It covers: Release channel options - **Invite-only channels:** Useful for alpha/beta testing. All release channels for Device Access Toolkit are currently invite-only. - **User invitations by email:** You can only invite testers who have [Meta accounts](https:/...
Use this file for implementing features related to this topic.
"""

Release channel options

- **Invite-only channels:** Useful for alpha/beta testing. All release channels for Device Access Toolkit are currently invite-only.
- **User invitations by email:** You can only invite testers who have [Meta accounts](https://developers.meta.com/horizon/blog/introducing-meta-accounts-what-developers-need-to-know/). Make sure to add the email associated with the tester’s Meta account when prompted to invite testers.
- **Tester autonomy:** Testers may accept or decline invitations and can remove themselves at any time.
- **Developer control:** You can revoke tester access at any point. You can also reinvite users you have previously revoked.
- **Limitations:** Up to 3 channels per integration, max 100 users per channel.

## Create a release channel

To set up a new release channel:

1. In the **Distribute** menu, click **Release channels** (right menu, adjacent to **Versions**).
2. Select **+ Create a release channel**.
3. Enter a unique **Name** and a clear **Description** for your channel. Click **Next**.
4. Select the **Version** you wish to distribute. You can update this selection whenever needed. Click **Next**.
5. Enter the email addresses of the testers you wish to invite.
   **Note:** These must be emails for already existing Meta Accounts (this is different from a Meta Managed Account). If the tester needs a Meta Account, they can create one at [meta.ai](http://meta.ai/) or by logging into the Meta AI app.
6. Click **Next**.
7. Review your selections, then click **Create release channel** to confirm. If you do not confirm by clicking this button, users will not receive the invitation.

## Manage test user access

Testers can belong to multiple release channels for one integration, such as for regression or parallel testing. Each invited tester must accept the email invitation to join a test group. Developers can remove testers, and testers can leave at any time.

**Note:** Release channels control a user's ability to register an app integration. Removing a user from a channel after they've registered will not unregister the connected app for Meta AI and the wearable device.

To view release channel details and manage test users, click **Edit** next to the channel. From here, you can also change the distributed version.

Test users can view the integrations they are testing at: [https://wearables.meta.com/invites](https://wearables.meta.com/invites)

## Manage permissions and switch release channels in the Meta AI app

People testing your integration can manage app permissions and switch release channels for your devices and connected apps in the Meta AI app. These settings help you control what your connected apps can access and allow you to try new features by joining different release channels.

## Manage permissions for connected apps

As a test user, managing permissions lets you control what each integration can access on your device.

To manage permissions:

1. Open the Meta AI App.
2. Go to the device menu and tap **Settings**.
3. Select **Connected Apps** to see a list of all apps linked to your Meta AI account.
4. Tap on an app to view its permissions.
5. Adjust specific permissions, e.g., for the camera:
    - You may see options like:
        - Always allow
        - Always ask
        - Don’t allow
6. Click **Confirm** to save your changes.

**Note:** Changes made to these settings will apply to all devices connected to your Meta AI app.

## Switch release channel

Release channels let testers choose between different versions of your integration.
