# plan.md — harbor-migration

> 작성일: 2026-03-17
> 상태: `검토 중`
> 현재 Phase: 덩어리 C (서버 사전 준비 및 샘플 테스트)

---

## 1. 목표

기존 Harbor(harbor.innogrid.com)의 전체 이미지 6,448개(1,080.30 GB)를 SRE Harbor(harbor.sre.local)로 마이그레이션한다.

### 성공 기준
- [ ] 전체 6,448개 이미지가 harbor.sre.local에 존재
- [ ] 샘플 이미지 pull 테스트 성공
- [ ] failed_migrate.csv 검토 및 재시도 완료
- [ ] 소스 Harbor Garbage Collection 실행

---

## 2. 환경 정보

### 서버 정보
- 작업 서버: 192.168.190.101
- SSH 포트: 8124
- SSH 계정: secloudit
- SSH 비밀번호: !$paas$!
- 작업 경로: /root/native-harbor/

### Harbor 정보
- 소스 Harbor: harbor.innogrid.com (sre-user / qwe1212!Q)
- 대상 Harbor: harbor.sre.local (sre-admin / qwe1212!Q)
- 대상 Harbor 스토리지: NFS (192.168.201.61) — 재배포 완료

### 분석 결과
- 총 프로젝트: 80개 / 총 레포지토리: 560개 / 총 이미지: 6,448개
- 전체 용량: 1,080.30 GB
- secloudit-helm: 전체 용량의 61.4% (663.58 GB) — PROJECT_FILTER로 별도 실행

---

## 3. 실행 방식

### tmux 세션 기반
- 장시간 작업을 위해 tmux 세션에서 실행
- 세션명: `harbor-migration` (본 실행) / `harbor-test` (샘플 테스트)
- SSH 연결 끊겨도 작업 지속

### 체크포인트
- `done_migrate.txt`: 마이그레이션 완료된 이미지 목록
- 재실행 시 완료된 항목은 SKIP

### EXIT trap
- 중단 시 잔여 이미지 자동 정리 (docker rmi)
- 서버에 기존 docker images 2,881개 존재 → 혼재 방지

---

## 4. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| 마이그레이션 범위 | 전체 이미지 | 백업/마이그레이션 구분 없이 단순화 |
| CSV 파일 | all_images.csv 단일 파일 | 관리 단순화 |
| 마이그레이션 방식 | pull → tag → push | Harbor 간 직접 복제보다 유연함 |
| secloudit-helm 처리 | 별도 실행 | 663 GB 단일 프로젝트로 분리 필요 |
| 실행 환경 | 서버 직접 실행 | harbor.sre.local 내부 DNS 제약 |

---

## 5. 구현 체크리스트

### 덩어리 A — harbor-backup.sh (취소)

- [~] A-1 ~ A-4: 백업 기능 불필요 — 전체 마이그레이션으로 변경

### 덩어리 B — harbor-migrate.sh ✅ 완료 (20a00c2)

- [x] B-1: 환경변수 설정 (SRC/DST Harbor 정보)
- [x] B-2: EXIT trap 구현
- [x] B-3: 체크포인트 로직 구현 (done_migrate.txt)
- [x] B-4: 마이그레이션 루프 구현 (pull → tag → push → rmi)
- [x] B-2-5: 프로젝트 자동생성 (대상 Harbor API 호출)
- [ ] B-5: MIGRATE_CSV 기본값 변경 (migrate_images.csv → all_images.csv)

### 덩어리 C — 서버 사전 준비 및 샘플 테스트

- [ ] C-0: 스크립트 서버 전송 (로컬에서 scp 실행)
  ```bash
  scp -P 8124 harbor-migrate.sh all_images.csv migrate_sample.csv \
      secloudit@192.168.190.101:/root/native-harbor/
  ```
  (migrate_sample.csv는 all_images.csv 상위 6줄로 새로 생성)

- [ ] C-1: 서버 사전 확인
  ```bash
  df -h /root
  cat /etc/docker/daemon.json
  docker images | wc -l
  ```

- [ ] C-2: insecure-registries 등록
  - harbor.sre.local을 /etc/docker/daemon.json에 추가
  ```bash
  sudo systemctl restart docker
  docker info | grep -A5 "Insecure Registries"
  ```

- [ ] C-3: 마이그레이션 샘플 테스트
  ```bash
  MIGRATE_CSV=migrate_sample.csv ./harbor-migrate.sh
  ```
  - 검증: harbor.sre.local에 이미지 존재 확인

- [ ] C-4: 체크포인트 동작 확인
  - 재실행 시 `SKIP (완료됨)` 출력 여부 확인

- [ ] C-5: PROJECT_FILTER 동작 확인
  ```bash
  PROJECT_FILTER=ai-platform ./harbor-migrate.sh 2>&1 | head -20
  ```

### 덩어리 D — 본 실행

- [ ] D-1: 마이그레이션 전체 실행 (secloudit-helm 제외)
  ```bash
  tmux new -s harbor-migration
  grep -v "^secloudit-helm" all_images.csv > all_except_helm.csv
  MIGRATE_CSV=all_except_helm.csv ./harbor-migrate.sh 2>&1 | tee logs/migrate-$(date +%Y%m%d).log
  ```

- [ ] D-2: secloudit-helm 별도 실행 (663 GB)
  ```bash
  PROJECT_FILTER=secloudit-helm MIGRATE_CSV=all_images.csv \
      ./harbor-migrate.sh 2>&1 | tee logs/migrate-helm-$(date +%Y%m%d).log
  ```

### 덩어리 E — 검증 및 완료

- [ ] E-1: 대상 Harbor 이미지 수 확인
  ```bash
  curl -sk -u "sre-admin:qwe1212!Q" "https://harbor.sre.local/api/v2.0/statistics" | jq
  ```

- [ ] E-2: 샘플 이미지 pull 테스트
  - 임의의 이미지 3개 선정하여 pull 테스트

- [ ] E-3: failed_migrate.csv 검토 및 재시도
  - 실패 원인 분석 후 재시도

- [ ] E-4: Garbage Collection 실행 (소스 Harbor)
  - Harbor UI에서 GC 실행 또는 API 호출

- [ ] E-5: 최종 보고서 작성
  - 마이그레이션 완료 건수, 실패 건수, 총 용량 정리

---

## 6. 리스크

| 리스크 | 영향도 | 대응 방안 |
|---|---|---|
| 네트워크 대역폭 (1,080 GB) | 높음 | 야간/주말 작업, tmux 세션 유지 |
| harbor.sre.local TLS | 높음 | insecure-registries 등록 (C-2) |
| 서버 디스크 임시 공간 | 중간 | EXIT trap으로 잔여 이미지 정리 |
| docker images 2,881개 혼재 | 중간 | EXIT trap + 즉시 rmi |
| secloudit-helm 663 GB | 중간 | PROJECT_FILTER로 분리 실행 |
| API Rate Limit | 낮음 | 동시 요청 없음, 순차 처리 |

---

## 7. 미확인 항목

| 항목 | 확인 방법 |
|---|---|
| 서버 /root 파티션 여유 공간 | `df -h /root` |
| daemon.json 기존 내용 | `cat /etc/docker/daemon.json` |

---

## 8. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.
-->

(검토 메모를 여기에 작성)

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-17 | 초안 작성 — 분석 완료, 덩어리 A/B 완료 상태로 시작 |
| 2026-03-17 | 백업 보류 — 마이그레이션만 우선 진행 |
| 2026-03-17 | 전체 마이그레이션으로 변경 — 백업/마이그레이션 구분 삭제, all_images.csv 사용 |
