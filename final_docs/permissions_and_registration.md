"""
FILE: permissions_and_registration.md
TOPIC: Permissions And Registration
SUMMARY: This document provides technical details on Permissions And Registration.
It covers: Permissions and registration The Wearables Device Access Toolkit separates app registration and device permissions. All permission grants occur through the Meta AI app. Permissions work across multiple linked wearables. Camera permissions are granted...
Use this file for implementing features related to this topic.
"""

Permissions and registration

## Overview

The Wearables Device Access Toolkit separates app registration and device permissions. All permission grants occur through the Meta AI app. Permissions work across multiple linked wearables.

Camera permissions are granted at the app level. However, each device will need to confirm permissions specifically, in turn allowing your app to support a set of devices with individual permissions.

To create an integration, follow this guidance to build your first integration for [Android](/docs/build-integration-android) or [iOS](/docs/build-integration-ios).

## Registration

Your app registers with the Meta AI app to be an permitted integration. This establishes the connection between your app and the glasses platform. Registration happens once through Meta AI app with glasses connected. Users see your app name in the list of connected apps. They can unregister anytime through the Meta AI app. You can also implement an unregistration flow is desired.

## Device permissions

After registration, request specific permissions (see possible values for [Android](https://wearables.developer.meta.com/docs/reference/android/dat/0.6/com_meta_wearable_dat_core_types_permission#enumeration_constants) and [iOS](https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.6/mwdatcore_permission#enumeration_constants)). The Meta AI app runs the permission grant flow. Users choose **Allow once** (temporary) or **Allow always** (persistent).
