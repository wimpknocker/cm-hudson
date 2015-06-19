rm $JENKINS_BUILD_DIR/packages/apps/OpenDelta/res/values/config.xml
echo '<?xml version="1.0" encoding="UTF-8"?>
    <!-- Output some debug strings -->
    <item type="bool" name="debug_output">false</item>
    <!-- Property to read for ROM version -->
    <string name="property_version">ro.cm.version</string>
    <!-- Property to read for device identifier -->
    <string name="property_device">ro.cm.device</string>
    <!-- %s is expanded to property_version value. .zip, .delta, .update, .sign extensions added when needed -->
    <string name="filename_base">cm-%s</string>
    <!-- Path deltas are stored, relative to sdcard root -->
    <string name="path_base">OpenDelta</string>
    <!-- URL base to find .delta files, %s is expanded to property_device value. Path is suffixed by (expanded) filename_base -->
    <string name="url_base_delta">https://download.wimpnether.net/nightlies/%s/</string>
    <!-- URL base to find .update and .sign files, %s is expanded to property_device value. Path is suffixed by (expanded) filename_base -->
    <string name="url_base_update">http://download.wimpnether.net/nightlies/%s/</string>
    <!-- URL base to find the full zip files, %s is expanded to property_device value. Path is suffixed by (expanded) filename_base -->
    <string name="url_base_full">http://download.wimpnether.net/full_builds/%s/</string>
    <!-- Applies whole-file signature delta. Adds one extra delta step. Required if recovery verifies signatures -->
    <item type="bool" name="apply_signature">true</item>
    <!-- (TWRP) Set this to false if the keys below aren't your ROM's -->
    <item type="bool" name="inject_signature_enable">true</item>
    <!-- (TWRP) Verification signatures to inject. Produced by 'dumpkey.jar' (out/host) of the platform.x509 key used to sign the ZIP file -->
    <string name="inject_signature_keys"><![CDATA[v2 {64,0x9d3ef4e7,{3451855145,2574857780,2212470067,2065828617,2220798544,1453138002,3035953543,349537325,3471576065,3709424322,1499657722,626083680,3508502098,135982109,2406850010,2674691998,3903782739,3673009508,3196976129,124737966,3727608735,3698514242,2926317182,2598715876,2200551045,3324466456,2027872794,1316834497,3538558575,4094723182,3091112109,152419065,961268200,2817719766,2542630774,735678394,2025086356,3319743251,3482513753,3754037486,2186326636,2162920719,1933319201,1362420666,3093979107,3944963833,3173846995,3307766644,4239176696,3380551792,3189093155,3679104199,4159403556,3373361362,737822358,2043192588,3446724037,2184123451,3680508975,492248740,1654088879,3739912969,188663922,4074712169},{2400585854,3884144496,312737665,3547448515,3596760612,2953776441,190371072,1980790627,3681130262,827104214,1597200957,1333455720,1391423898,4233042842,3284284880,50168935,2424437529,2771213818,3715896496,3320142743,3649069246,2702994054,839870558,1257344415,3116165843,4195920375,2497396347,1334871168,3550010104,64795091,3042249326,4155098628,123980023,3500559217,1825888674,443352554,3891428201,2484397377,4136956616,4201065713,2547196505,3411971111,2135688607,393830937,4198844531,3826748593,3979050977,1220766766,3592470842,2278136,1841247501,3507376964,3313320668,3849023694,2185649624,3043141327,1601153541,939583339,2083130022,3508853409,2068728550,3713282728,2402412627,1764295415}}]]></string>
    <!-- (TWRP) Add secure mode setting. Requires 'apply_signature' and 'inject_signature_enable'. Limits flashing to TWRP only, verifies ZIP signature in TWRP, disables auto-flashing of additional ZIPs -->
    <item type="bool" name="secure_mode_enable">true</item>
    <!-- (TWRP) Requires 'secure_mode_enable'. Decides whether the default setting for secure mode is enabled (true) or disabled (false) -->
    <item type="bool" name="secure_mode_default">true</item>
    <!--
    	Devices (detected using property_device) which may crash while downloading/patching/verifying when the screen is off.
    	This appears to be an issue with the fuse daemon, but the cause has not yet been found or fixed. Until the issue is
    	repaired, this is a stop-gap solution.
    -->
    <string-array name="keep_screen_on_devices">
        <item>i9100</item>
        <item>n7000</item>
        <item>i777</item>
    </string-array>
</resources>' > $JENKINS_BUILD_DIR/packages/apps/OpenDelta/res/values/config.xml
