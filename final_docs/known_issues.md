"""
FILE: known_issues.md
TOPIC: Known Issues
SUMMARY: This document provides technical details on Known Issues.
It covers: Known issues | Issue | Workaround | | --- | --- | | If there isn't an internet connection present, your app may fail to connect with the Wearables Developer Access Toolkit, and you may not be able to register your app in developer mode. | An internet...
Use this file for implementing features related to this topic.
"""

Known issues

## Wearables Device Access Toolkit

| Issue | Workaround |
| --- | --- |
| If there isn't an internet connection present, your app may fail to connect with the Wearables Developer Access Toolkit, and you may not be able to register your app in developer mode. | An internet connection is required for registration. |
| Streams that are started with the glasses doffed are paused when they glasses are donned. | None at this time. You can unpause by tapping the side of your glasses. |
| If the glasses' hinges are closed while streaming, the underlying service in the glasses may get stuck. Camera will stop working (including non Wearables Device Access Toolkit capture cases, like pressing capture button) until glasses are rebooted. | Restart the glasses with the power switch. |
| **[iOS-only]** Meta Ray-Ban Display glasses don't play "Experience paused"/"Experience started" when pausing or resuming the session using captouch gestures. | This issue will be resolved in a future SDK release. |

## Wearables Developer Center

| Issue | Workaround |
| --- | --- |
| Email addresses of members invited to a release channel must already be associated with a Meta account. | Verify anyone you invite to a release channel has set up a Meta account at [meta.ai](https://www.meta.ai/). |
| Users logged into [developers.meta.com](https://developers.meta.com/) (Meta Horizon) may face an error with links from the Wearables Developer Center because it uses a different domain ([developer.meta.com](https://developer.meta.com/)). | Logout from [developers.meta.com](https://developers.meta.com/) before signing up for the Wearables Developer Center. |
