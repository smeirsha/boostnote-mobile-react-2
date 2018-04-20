
#!/bin/bash

# Reassign to trim the trailing newline on APPLE_PROV_PROFILE_UUID
export UUID=$(echo -e $APPLE_PROV_PROFILE_UUID | tr -d '\n')
export FILE=/Users/vsts/Library/MobileDevice/Provisioning\ Profiles/$UUID.mobileprovision

echo "File path: $FILE"

/usr/bin/security cms -D -i "$FILE" >> temp_profile.plist
# Ignoring stdout error since IsXcodeManaged does not exists in old provisioning profile
IS_AUTO=$(/usr/libexec/PlistBuddy -c "print IsXcodeManaged" temp_profile.plist 2>/dev/null)
SIGN_IDENTITY="iPhone Developer"

# Determine old provisioning profile type 
if [[ $IS_AUTO == "" ]]; 
then 
   NAME=$(/usr/libexec/PlistBuddy -c "print Name" temp_profile.plist)
   echo "Name: $NAME"
   if [[ $NAME == 'iOS Team'* ]] || [[ $NAME == 'Mac Team'* ]]; 
   then 
     IS_AUTO=true
   else 
     IS_AUTO=false
   fi
fi
echo "IsAuto: $IS_AUTO"

if  [[ $IS_AUTO == false ]] ;
then
    echo "Signing style: Manual"
    echo "##vso[task.setvariable variable=SIGNING_OPTION]manual"
    echo '##vso[task.setvariable variable=SIGN_ARGS]PROVISIONING_PROFILE_SPECIFIER=""'
else
    echo "Signing style: Automatic"
    echo "##vso[task.setvariable variable=SIGNING_OPTION]auto"
    if [[ $APPLE_CERTIFICATE_SIGNING_IDENTITY == 'Mac Developer'* ]]; 
    then 
       SIGN_IDENTITY="Mac Developer"
    fi
     echo "SignIdentity: $SIGN_IDENTITY"
    echo '##vso[task.setvariable variable=SIGN_ARGS]PROVISIONING_PROFILE_SPECIFIER="" PROVISIONING_PROFILE="" CODE_SIGN_IDENTITY="'$SIGN_IDENTITY'"'
fi
rm temp_profile.plist


# Use sed to quote filepaths which may contain spaces.
BROKEN_POD_FILES=$(grep -l -r 'NO_SIGNING/' --include '*.pbxproj' . | sed -e 's/^/"/g' -e 's/$/"/g')

if [[ ! -z "$BROKEN_POD_FILES" ]];
then
 echo 'Fixing CocoaPods projects with "NO_SIGNING/" provisioning profiles. See https://github.com/CocoaPods/CocoaPods/issues/7038'
 echo $BROKEN_POD_FILES | xargs perl -pi -e 's/PROVISIONING_PROFILE_SPECIFIER = NO_SIGNING\//CODE_SIGNING_ALLOWED = NO/g'
fi