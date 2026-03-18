# research.md — harbor-migration

> 작성일: 2026-03-17
> 상태: `완료`
> 목적: 기존 Harbor 이미지 분석 결과 정리 (분석은 이미 완료됨)

---

## 1. 자동화 대상

### Harbor 환경
| 구분 | URL | 용도 |
|---|---|---|
| 소스 Harbor | harbor.innogrid.com | 기존 이미지 저장소 |
| 대상 Harbor | harbor.sre.local | SRE 전용 신규 저장소 |

### 프로젝트/레포지토리 현황
- 총 프로젝트: 80개
- 총 레포지토리: 560개
- 총 이미지(태그): 6,448개

---

## 2. 기술 스택 및 버전

| 항목 | 버전/도구 | 비고 |
|---|---|---|
| 스크립트 언어 | Bash | POSIX 호환 |
| API | Harbor API v2.0 | REST API |
| HTTP 클라이언트 | curl | -sk 옵션 (TLS 무시) |
| JSON 파서 | jq | 필수 의존성 |
| 컨테이너 런타임 | docker | pull/push/save/rmi |
| 세션 관리 | tmux | 장시간 작업용 |

---

## 3. 전체 이미지 현황

| 항목 | 값 |
|---|---|
| 전체 이미지 | 6,448개 |
| 전체 용량 | 1,080.30 GB |

### TOP 10 프로젝트 (용량 기준)

| 순위 | 프로젝트 | 이미지 수 | 용량 |
|---|---|---|---|
| 1 | secloudit-helm | 2,846개 | 663.58 GB |
| 2 | ai-platform | 49개 | 50.97 GB |
| 3 | secloudit | 858개 | 44.95 GB |
| 4 | devops-backend | 212개 | 35.32 GB |
| 5 | kubeflow | 89개 | 31.72 GB |
| 6 | secloudit-java | 163개 | 30.25 GB |
| 7 | secloudit-ui | 636개 | 24.74 GB |
| 8 | soongsil-openlab | 148개 | 23.47 GB |
| 9 | devops-util | 7개 | 18.27 GB |
| 10 | gitbook | 39개 | 16.11 GB |

---

## 4. 주요 관찰

### secloudit-helm 프로젝트 특이사항
- 전체 용량의 **61.4%** 차지 (663.58 GB / 1,080.30 GB)
- 이미지 수: 2,846개 (전체의 44%)
- **별도 실행 필요**: PROJECT_FILTER 환경변수로 분리 처리

### 서버 환경 특이사항
- 작업 서버(192.168.190.101)에 기존 docker images 2,881개 존재
- pull 후 즉시 rmi 필수 (디스크 공간 확보)
- harbor.sre.local은 내부 DNS만 등록됨 → 로컬 실행 불가

### 스크립트 공통 기능
- EXIT trap: 중단 시 잔여 이미지 자동 정리
- 체크포인트: done_migrate.txt로 재시작 가능
- 멀티태그 지원: 동일 digest의 여러 태그 처리

---

## 5. 의존성 및 실행 순서

### 실행 순서

```
[C-0] 스크립트/CSV 서버 전송 (scp)
    ↓
[C-1] 서버 사전 확인 (df, daemon.json, docker images)
    ↓
[C-2] insecure-registries 등록 (harbor.sre.local)
    ↓
[C-3~C-5] 샘플 테스트
    ↓
[D-1] 마이그레이션 실행 (secloudit-helm 제외)
    ↓
[D-2] secloudit-helm 별도 실행 (663 GB)
    ↓
[E-1~E-5] 검증 및 완료
```

### 선행 조건
- 서버 SSH 접속 가능 (192.168.190.101:8124)
- docker daemon 실행 중
- jq 설치됨

### 후행 작업
- 소스 Harbor Garbage Collection
- 최종 보고서 작성

---

## 6. 시크릿 항목 (값 기재 금지)

| 항목 | 용도 | 저장 위치 |
|---|---|---|
| `SSH_PASSWORD` | 작업 서버 접속 | CLAUDE.md |
| `SRC_HARBOR_USER` | 소스 Harbor 인증 | 스크립트 내 |
| `SRC_HARBOR_PASS` | 소스 Harbor 인증 | 스크립트 내 |
| `DST_HARBOR_USER` | 대상 Harbor 인증 | 스크립트 내 |
| `DST_HARBOR_PASS` | 대상 Harbor 인증 | 스크립트 내 |

---

## 7. 리스크

| 리스크 | 영향도 | 대응 방안 |
|---|---|---|
| 네트워크 대역폭 (1,080 GB 전송) | 높음 | 야간/주말 작업, tmux 세션 유지 |
| harbor.sre.local TLS 인증서 | 높음 | insecure-registries 등록 (C-2) |
| 서버 디스크 임시 공간 부족 | 중간 | EXIT trap으로 잔여 이미지 정리 |
| docker images 2,881개 혼재 | 중간 | EXIT trap + 즉시 rmi |
| secloudit-helm 663 GB 단일 프로젝트 | 중간 | PROJECT_FILTER로 분리 실행 |
| API Rate Limit | 낮음 | 동시 요청 없음, 순차 처리 |
| 네트워크 불안정 | 중간 | 체크포인트로 재시작 가능 |

---

## 8. 미확인 항목

| 항목 | 영향 범위 | 확인 방법 |
|---|---|---|
| 서버 /root 파티션 여유 공간 | 마이그레이션 실행 가능 여부 | `df -h /root` |
| daemon.json 기존 내용 | insecure-registries 등록 방식 | `cat /etc/docker/daemon.json` |

---

## 메모

### 산출물 현황
- harbor-analyze.sh: 완료 (분석 스크립트, CSV 생성)
- harbor-migrate.sh: 완료 (EXIT trap, 체크포인트, 멀티태그, 프로젝트 자동생성 포함)
- all_images.csv: 완료 (6,448개 전체 이미지)
- migrate_sample.csv: all_images.csv 상위 6줄로 재생성 필요

### 분석 완료 확인
모든 분석 작업은 이전 세션에서 완료됨. 현재 단계는 서버 전송 및 실행 단계(덩어리 C~E).
