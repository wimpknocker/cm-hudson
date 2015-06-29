#!/bin/bash

rm packages/apps/CMUpdater/res/values/config.xml
echo '<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright (C) 2012 The CyanogenMod Project
     Licensed under the GNU GPLv2 license
     The text of the license can be found in the LICENSE file
     or at https://www.gnu.org/licenses/gpl-2.0.txt
-->
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
    <!-- CMUpdate Config Strings -->
    <string name="conf_update_server_url_def" translatable="false">http://download.wimpnether.net/api</string>
    <string name="conf_changelog_url" translatable="false">http://localhost/changelog.xml</string>
    <bool name="alternateIsInternal">false</bool>
</resources>' > packages/apps/CMUpdater/res/values/config.xml
