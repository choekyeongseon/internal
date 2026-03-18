# research.md — harbor-migration

> 작성일: 2026-03-17
> 상태: `완료`
> 목적: 소스 Harbor 이미지 분류 및 SRE Harbor 마이그레이션 자동화 요구사항 분석

---

## 1. 자동화 대상

### 무엇을 만드는가
- 소스 Harbor 전체 이미지 분류 및 선택적 마이그레이션
- 최근 2년 내 사용된 이미지 → SRE Harbor로 마이그레이션
- 2년 이상 미사용 이미지 → 백업 저장소로 이동

### 핵심 제약 조건
- Phase 5 이전까지 소스 Harbor 이미지 삭제 금지 (원본 보존)
- digest 검증 필수 (데이터 무결성)
- secloudit-helm 프로젝트 별도 처리 필요 (663.58 GB)

---

## 2. 기술 스택 및 버전

| 항목 | 버전 | 비고 |
|---|---|---|
| Harbor API | v2 | 소스/대상 모두 동일 |
| 소스 Harbor | v2.11.2 | harbor.innogrid.com |
| 대상 Harbor | 미확인 | harbor.sre.local |
| CLI 도구 | bash | set -euo pipefail |
| 이미지 전송 | skopeo 또는 docker CLI | 선택 가능 |

---

## 3. 아키텍처

### 전체 구조
```
[소스 Harbor]                    [대상 Harbor]
harbor.innogrid.com  ────────►  harbor.sre.local
192.168.190.101                 192.168.201.12
계정: sre-user                  계정: sre-admin

                 [분석 결과 파일]
                 ├── all_images.csv      (전체 6,448개)
                 ├── migrate_images.csv  (마이그레이션 4,295개)
                 └── backup_images.csv   (백업 2,153개)
```

### 주요 스크립트 역할
- `harbor-analyze.sh`: 이미지 분석 (완료)
- `harbor-migrate.sh`: 마이그레이션 실행 (구현 예정)
- `harbor-backup.sh`: 백업 실행 (구현 예정)

### 의존성 관계
- `harbor-migrate.sh` → `migrate_images.csv`: 마이그레이션 대상 목록 참조
- `harbor-backup.sh` → `backup_images.csv`: 백업 대상 목록 참조

---

## 4. 핵심 변수/설정값

```bash
# 기준일
CUTOFF_DATE=2024-03-17

# 마이그레이션 대상
MIGRATE_COUNT=4295
MIGRATE_SIZE_GB=914.84

# 백업 대상
BACKUP_COUNT=2153
BACKUP_SIZE_GB=165.46

# 최대 단일 프로젝트
MAX_PROJECT="secloudit-helm"
MAX_PROJECT_SIZE_GB=663.58  # 전체의 72.5%
```

### 주요 환경 변수
- `HARBOR_SOURCE_URL`: 소스 Harbor URL
- `HARBOR_SOURCE_USER`: 소스 Harbor 계정
- `HARBOR_TARGET_URL`: 대상 Harbor URL
- `HARBOR_TARGET_USER`: 대상 Harbor 계정

---

## 5. 의존성 및 순서

### Phase 2: SRE Harbor 사전 준비
1. SRE Harbor 연결 테스트
2. 프로젝트 생성 (소스와 동일 구조)
3. 백업 저장소 준비

### Phase 3: 백업 실행
1. 백업 대상 이미지 NFS/로컬 저장소로 복제
2. 무결성 검증 (digest 비교)

### Phase 4: 마이그레이션 실행
1. 마이그레이션 대상 이미지 전송
2. digest 검증
3. pull 테스트

### Phase 5: 정리 (별도 승인 필요)
1. 구 Harbor 이미지 삭제
2. Garbage Collection 실행
3. 최종 보고서 작성

---

## 6. 시크릿 항목 (값 기재 금지)

| 항목 | 용도 | 저장 위치 |
|---|---|---|
| `vault_harbor_source_password` | 소스 Harbor 인증 | Vault |
| `vault_harbor_target_password` | 대상 Harbor 인증 | Vault |

---

## 7. 변경 영향 범위

### 소스 Harbor
- Phase 5 전까지 이미지 삭제 없음 (읽기만)
- harbor-analyze.sh로 분석 완료

### 대상 Harbor (SRE)
- 프로젝트 생성 (신규)
- 이미지 push (914.84 GB)

### 네트워크 영향
- secloudit-helm 처리 시 네트워크 대역폭 집중 사용
- 663.58 GB 단일 프로젝트 전송 시 야간/주말 작업 권장

### 사이드이펙트 체크 항목
- [x] 기존 API 응답 형식 변경 여부: 없음
- [x] 데이터베이스 스키마 변경 여부: 없음 (Harbor 내부)
- [ ] 외부 서비스 호출 패턴 변경 여부: 이미지 pull 경로 변경됨
- [x] 설정 파일 형식 변경 여부: 없음

---

## 8. 미확인 항목 (# TODO)

| 항목 | 영향 범위 | 확인 방법 |
|---|---|---|
| SRE Harbor 스토리지 가용 용량 | 마이그레이션 가능 여부 | SRE팀 문의 |
| secloudit-helm 별도 처리 전략 | 전송 방식 결정 | 분할 전송 vs 직접 복제 검토 |
| 백업 저장소 경로 및 용량 | 백업 실행 가능 여부 | 인프라팀 문의 |
| 야간/주말 작업 일정 | 네트워크 영향 최소화 | 운영팀 협의 |

---

## 메모

- secloudit-helm이 전체 마이그레이션 용량의 72.5%를 차지하므로 별도 전략 필수
- 이미지 전송 후 반드시 digest 검증 수행
- Phase 5(이미지 삭제)는 별도 승인 프로세스 후 진행
