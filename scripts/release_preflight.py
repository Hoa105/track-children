"""Validate public mobile release inputs without contacting providers or printing secrets."""
import argparse
import ipaddress
import json
from pathlib import Path
import re
import shutil
import sys
from urllib.parse import urlsplit

ROOT=Path(__file__).resolve().parents[1]
PUBLIC_KEYS={'API_BASE_URL','DEMO_MODE','GOOGLE_SERVER_CLIENT_ID','GOOGLE_IOS_CLIENT_ID','APPLE_SERVICE_ID','APPLE_REDIRECT_URI'}

def public_https(value):
    if not isinstance(value,str):return False
    try:
        url=urlsplit(value)
        host=url.hostname or ''
        if url.scheme!='https' or not host or url.username or url.password or url.query or url.fragment:
            return False
        if host.lower()=='localhost' or '.' not in host or 'REPLACE' in value.upper():return False
        try:return ipaddress.ip_address(host).is_global
        except ValueError:return not host.endswith(('.local','.test','.invalid','.example'))
    except (ValueError,TypeError):return False

def errors(config,platform):
    failures=[]
    if not isinstance(config,dict):return ['Release configuration must be a JSON object.']
    if set(config)-PUBLIC_KEYS:failures.append('Only documented public Dart defines are allowed; never include backend secrets.')
    for key in ('API_BASE_URL','GOOGLE_SERVER_CLIENT_ID','APPLE_SERVICE_ID','APPLE_REDIRECT_URI'):
        if not isinstance(config.get(key),str) or not config[key] or 'REPLACE' in config[key].upper():failures.append('Missing release value: '+key)
    if not public_https(config.get('API_BASE_URL','')) or urlsplit(config.get('API_BASE_URL','')).path.rstrip('/')!='/api/v1':
        failures.append('API_BASE_URL must be public HTTPS ending in /api/v1.')
    if not public_https(config.get('APPLE_REDIRECT_URI','')):failures.append('APPLE_REDIRECT_URI must be public HTTPS.')
    if str(config.get('DEMO_MODE','')).lower()!='false':failures.append('DEMO_MODE must explicitly be false.')
    if platform=='ios' and (not config.get('GOOGLE_IOS_CLIENT_ID') or 'REPLACE' in str(config['GOOGLE_IOS_CLIENT_ID']).upper()):
        failures.append('Missing release value: GOOGLE_IOS_CLIENT_ID')
    return failures

def signing_errors(platform):
    if platform=='ios':
        issues=[]
        if sys.platform!='darwin' or not shutil.which('xcodebuild'):issues.append('TestFlight builds require a configured macOS/Xcode host.')
        project=(ROOT/'mobile/ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
        if 'PRODUCT_BUNDLE_IDENTIFIER = com.example.' in project:issues.append('Replace the sample iOS bundle identifier with the registered identifier.')
        return issues
    path=ROOT/'mobile/android/key.properties'
    if not path.is_file():return ['Android owner-controlled release keystore configuration is missing.']
    props={}
    for line in path.read_text(encoding='utf-8').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key,value=line.split('=',1);props[key.strip()]=value.strip()
    issues=[]
    for key in ('applicationId','storeFile','storePassword','keyAlias','keyPassword'):
        if not props.get(key) or 'REPLACE' in props[key].upper():issues.append('Missing Android signing value: '+key)
    appid=props.get('applicationId','')
    if appid.startswith('com.example.') or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+',appid):
        issues.append('Use the registered Android application ID.')
    # Keystore existence and passwords are finally verified by Gradle/apksigner.
    return issues

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',required=True,type=Path)
    parser.add_argument('--platform',required=True,choices=['android','ios']);args=parser.parse_args()
    try:config=json.loads(args.config.read_text(encoding='utf-8'))
    except (OSError,ValueError):print('Release configuration file is missing or invalid.');return 1
    issues=errors(config,args.platform)+signing_errors(args.platform)
    print(json.dumps({'readyToAttemptBuild':not issues,'issues':issues,'note':'Does not verify provider delivery, signing validity, account access, migration approval or store review.'},indent=2))
    return 1 if issues else 0

if __name__=='__main__':sys.exit(main())
