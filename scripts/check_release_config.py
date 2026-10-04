#!/usr/bin/env python3
"""설정 값은 출력하지 않고 출시 입력 파일의 존재와 프로젝트 일치만 검사합니다."""
import json
import plistlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
config = root / 'LocalBusApp/Configurations/Secrets.xcconfig'
firebase = root / 'LocalBusApp/LocalBusApp/GoogleService-Info.plist'
lock = root / 'LocalBusApp/LocalBusApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
if not config.is_file():
    raise SystemExit('Secrets.xcconfig가 없습니다. README의 설정 주입 절차를 확인하세요.')
if not firebase.is_file():
    raise SystemExit('GoogleService-Info.plist가 없습니다. 승인된 Firebase 설정을 주입하세요.')
with firebase.open('rb') as f:
    value = plistlib.load(f)
if value.get('BUNDLE_ID') != 'kr.co.lee.jangyusasang' or not all(value.get(k) for k in ('GOOGLE_APP_ID', 'GCM_SENDER_ID', 'API_KEY', 'PROJECT_ID')):
    raise SystemExit('Firebase 설정의 필수 항목 또는 앱 식별자가 올바르지 않습니다.')
if not lock.is_file() or not json.loads(lock.read_text()).get('pins'):
    raise SystemExit('의존성 잠금 파일이 없습니다.')
print('출시 설정 파일 검사 통과 (설정 값 출력 없음)')
