# LocalBus 개인정보 처리방침

**최종 수정일: 2026년 4월 6일**

---

## 1. 개요

LocalBus(이하 "앱")는 개발자가 직접 사용자의 개인정보를 수집하거나 저장하지 않습니다. 다만 앱 기능 제공 과정에서 GitHub, Apple, Kakao Mobility 등 제3자 서비스가 네트워크 접속 정보 또는 위치 관련 정보를 처리할 수 있으며, 해당 처리는 각 서비스 제공자의 정책에 따를 수 있습니다.

---

## 2. 수집하는 개인정보

**앱 개발자가 직접 수집·저장하는 개인정보는 없습니다.**

- 회원가입, 로그인이 없습니다.
- 이름, 이메일, 전화번호 등 개인 식별 정보를 개발자가 수집하지 않습니다.
- 광고 식별자(IDFA), 분석 SDK, 사용자 추적 SDK를 사용하지 않습니다.
- 현재 위치는 사용자가 허용한 경우 지도 화면과 정류장 거리 표시 기능에 한해 사용되며, 개발자 서버에 저장되지 않습니다.

---

## 3. 앱이 사용하는 데이터

### 3.1 시간표 데이터
- 앱은 버스 시간표 데이터를 외부 서버(GitHub)에서 불러옵니다.
- 이 과정에서 GitHub가 사용자의 IP 주소, User-Agent, 요청 로그 등 네트워크 접속 정보를 처리할 수 있습니다.
- 앱 개발자는 위 접속 로그를 별도로 조회하거나 개인을 식별하는 용도로 사용하지 않습니다.

### 3.2 지도 및 현재 위치 기능
- 앱은 Apple MapKit을 사용하여 정류장 위치와 노선 지도를 표시합니다.
- 사용자가 현재 위치 기능을 허용하면, 현재 위치는 지도 중심 이동과 정류장까지의 거리 계산에 사용됩니다.
- 지도 기능 제공을 위해 Apple이 네트워크 정보 및 위치 관련 정보를 처리할 수 있으며, 앱 개발자는 이를 별도로 저장하지 않습니다.

### 3.3 실시간 교통 정보
- 앱은 Kakao Mobility API를 사용해 출발지와 도착지 정류장 사이의 예상 소요시간을 조회할 수 있습니다.
- 이 과정에서 출발지·도착지 정류장 좌표와 사용자의 네트워크 접속 정보가 Kakao Mobility에 전달될 수 있습니다.
- 사용자의 현재 위치는 Kakao Mobility API로 전송되지 않습니다.

### 3.4 알림
- 사용자가 알림을 설정하면 기기의 로컬 알림 기능을 사용합니다.
- 알림 정보는 기기에만 저장되며 외부로 전송되지 않습니다.

### 3.5 캐시 데이터
- 시간표 데이터는 오프라인 사용을 위해 기기에 캐시됩니다.
- 캐시 데이터는 사용자 기기에만 저장됩니다.

---

## 4. 제3자 서비스

본 앱은 다음 제3자 서비스를 사용합니다:

| 서비스 | 용도 | 처리될 수 있는 정보 |
|--------|------|---------------------|
| GitHub Raw | 시간표 데이터 제공 | 접속 IP 주소, User-Agent, 요청 로그 등 네트워크 정보 |
| Apple MapKit | 지도 표시 및 현재 위치 기능 | 지도 요청 정보, 접속 IP 주소, 사용자가 허용한 경우 현재 위치 관련 정보 |
| Kakao Mobility API | 실시간 교통 소요시간 조회 | 출발지·도착지 정류장 좌표, 접속 IP 주소 등 네트워크 정보 |

---

## 5. 아동 개인정보

본 앱은 만 14세 미만 아동의 개인정보를 의도적으로 수집하지 않습니다.

---

## 6. 데이터 보관, 삭제 및 권한 철회

- 앱 개발자는 별도의 서버에 개인정보를 보관하지 않습니다.
- 시간표 캐시는 새 데이터로 갱신될 때 교체되며, 앱을 삭제하면 기기에서 제거됩니다.
- 로컬 알림은 앱 내 기능 또는 iOS 알림 설정에서 언제든지 변경하거나 해제할 수 있습니다.
- 위치 권한은 iOS 설정에서 언제든지 철회할 수 있습니다.
- 개발자가 보관하는 서버 측 개인정보가 없으므로 별도의 계정 데이터 삭제 절차는 제공하지 않습니다.

---

## 7. 개인정보 처리방침 변경

개인정보 처리방침이 변경되는 경우, 앱 업데이트 또는 이 페이지를 통해 공지합니다.

---

## 8. 문의

개인정보 처리방침에 관한 문의는 아래로 연락해 주세요.

- **이메일**: help@localbus.com
- **GitHub**: https://github.com/unib35/LocalBus

---

# LocalBus Privacy Policy

**Last Updated: April 6, 2026**

---

## 1. Overview

LocalBus ("the App") does not directly collect or store users' personal information on the developer's own servers. However, third-party services such as GitHub, Apple, and Kakao Mobility may process network connection information or location-related information while providing app features, and such processing may be governed by each provider's own policies.

---

## 2. Personal Information We Collect

**The developer does not directly collect or store personal information.**

- No sign-up or login required.
- The developer does not collect names, emails, phone numbers, or other personally identifiable information.
- The app does not use IDFA, analytics SDKs, or user-tracking SDKs.
- When you grant location permission, your current location is used only for map and stop-distance features and is not stored on the developer's servers.

---

## 3. Data the App Uses

### 3.1 Timetable Data
- The app fetches bus schedule data from an external server (GitHub).
- GitHub may process your IP address, User-Agent, and request logs while serving this data.
- The developer does not separately access these logs to identify individual users.

### 3.2 Maps and Current Location
- The app uses Apple MapKit to display bus stops and route maps.
- If you allow location access, your current location is used to center the map and estimate the distance to a stop.
- Apple may process network and location-related information to provide map features, and the developer does not separately store that data.

### 3.3 Real-Time Traffic Information
- The app may use the Kakao Mobility API to estimate travel time between route stops.
- In this process, route stop coordinates and network connection information may be transmitted to Kakao Mobility.
- Your current location is not sent to the Kakao Mobility API.

### 3.4 Notifications
- When you set notifications, the app uses your device's local notification feature.
- Notification data is stored only on your device and is not transmitted externally.

### 3.5 Cache Data
- Schedule data is cached on your device for offline use.
- Cache data is stored only on your device.

---

## 4. Third-Party Services

This app uses the following third-party services:

| Service | Purpose | Data That May Be Processed |
|---------|---------|----------------------------|
| GitHub Raw | Timetable data delivery | IP address, User-Agent, request logs, and other network information |
| Apple MapKit | Map rendering and current-location features | Map request data, IP address, and location-related information when permitted by the user |
| Kakao Mobility API | Real-time traffic duration lookup | Route stop coordinates, IP address, and other network information |

---

## 5. Children's Privacy

This app does not knowingly collect personal information from children under 14 years of age.

---

## 6. Data Retention, Deletion, and Revoking Permissions

- The developer does not maintain separate servers that store personal information.
- Cached timetable data is replaced when refreshed and removed from the device when the app is deleted.
- Local notifications can be changed or disabled within the app or in iOS notification settings.
- Location permission can be revoked at any time in iOS Settings.
- Because the developer does not hold server-side personal information, there is no separate account-data deletion workflow.

---

## 7. Changes to This Policy

If this privacy policy changes, we will notify you through app updates or this page.

---

## 8. Contact

For questions about this privacy policy, please contact us:

- **Email**: help@localbus.com
- **GitHub**: https://github.com/unib35/LocalBus
