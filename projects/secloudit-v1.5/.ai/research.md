# research.md — secloudit-v1.5

> 작성일: 2026-03-16
> 상태: `완료`

---

## 1. 자동화 대상

### 무엇을 만드는가
- **VM 3종에 podman-compose 기반 컴포넌트 배포**
  - Image Registry VM: docker-registry + docker-registry-web
  - SE 노드 VM: MySQL → SECloudit Console
  - Logging VM: MongoDB → FluentD Forward

- **K8s 클러스터 안에 kubectl apply 배포**
  - FluentD Agent: DaemonSet (각 K8s 노드에서 로그 수집 → Logging VM 전달)
  - Tekton Pipelines + Triggers

### 핵심 개념
- SECloudit은 K8s를 관리하는 주체 (K8s 안에 배포되는 게 아님)
- 솔루션 컴포넌트는 별도 VM에 podman 컨테이너로 배포
- K8s 클러스터는 SECloudit이 관리하는 대상

---

## 2. 기술 스택 및 버전

### 기반 환경
| 항목 | 버전 | 비고 |
|---|---|---|
| Ansible | - | playbook 기반 배포 |
| Podman + podman-compose | - | 컨테이너 런타임 |
| Rocky Linux | 9.1 | VM OS |

### OSS 버전표 (v1.5 기준)

| 컴포넌트 | 버전 |
|---|---|
| Kubernetes | 1.19.16 ~ 1.23.8 (현장별 상이, 우리 환경: 1.23.17) |
| Tekton Pipeline | 0.28.3 |
| Tekton Listener (Triggers) | 0.18.0 |
| Prometheus | 2.20.0 |
| FluentD | 1.13 |
| MySQL | 8.0.31 |
| MongoDB | 5.0.14 |
| docker-registry | 15.0.2 |
| Harbor (선택) | 2.7.1 |

---

## 3. 아키텍처

### 솔루션 VM 3종 구성

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECloudit v1.5 배포 구조                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Image Registry VM]                                            │
│  ├── docker-registry (port 5000)                                │
│  └── docker-registry-web (port 8080)                            │
│                                                                 │
│  [SE 노드 VM]                                                    │
│  ├── MySQL (port 3306)                                          │
│  └── SECloudit Console (port 9080)                              │
│                                                                 │
│  [Logging VM]                                                   │
│  ├── MongoDB (port 27017)                                       │
│  └── FluentD Forward (port 24224)                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### in-cluster 구성 (K8s 클러스터 내부)

```
┌─────────────────────────────────────────────────────────────────┐
│                    K8s 클러스터 (관리 대상)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [FluentD Agent]                                                │
│  └── DaemonSet: 각 노드에서 로그 수집 → Logging VM 전달            │
│                                                                 │
│  [Tekton]                                                       │
│  ├── Tekton Pipelines (v0.28.3)                                 │
│  └── Tekton Triggers (v0.18.0)                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 포트 구성

| VM | 컴포넌트 | 포트 |
|---|---|---|
| Image Registry | docker-registry | 5000 |
| Image Registry | docker-registry-web | 8080 |
| SE 노드 | MySQL | 3306 |
| SE 노드 | SECloudit Console | 9080 |
| Logging | MongoDB | 27017 |
| Logging | FluentD Forward | 24224 |

---

## 4. 핵심 변수/설정값

### 이미지 레지스트리
- docker-registry 주소: `{{ registry_host }}:5000`
- docker-registry-web: `{{ registry_host }}:8080`

### FluentD 설정
- FluentD Forward 포트: 24224
- FLUENT_FORWARD_HOST: Logging VM IP (# TODO: 확인 필요)
- CLUSTER_DIVIDE_VALUE: 클러스터 구분자 (# TODO: 확인 필요)

### SECloudit Console
- Console 포트: 9080
- MySQL 포트: 3306

### MongoDB
- MongoDB 포트: 27017

---

## 5. 의존성 및 순서

### 설치 순서 (변경 금지)

```
1. Image Registry VM  — docker-registry 구동 (이미지 저장소 먼저)
        ↓
2. SE 노드 VM         — MySQL 구동 → healthy 확인 → SECloudit Console 구동
        ↓
3. Logging VM         — MongoDB 구동 → FluentD Forward 구동
        ↓
4. in-cluster         — FluentD Agent DaemonSet 배포 (K8s Master에서 kubectl apply)
        ↓
5. in-cluster         — Tekton Pipelines(v0.28.3) → Tekton Triggers(v0.18.0) 배포
```

### 컴포넌트 내부 의존성
- MySQL healthy 확인 후 Console 기동
- MongoDB 기동 후 FluentD Forward 기동
- Tekton Pipelines 설치 후 Triggers 설치

---

## 6. 시크릿 항목 (값 기재 금지)

| 변수명 | 용도 |
|---|---|
| vault_mysql_root_password | MySQL root 비밀번호 |
| vault_mongodb_root_password | MongoDB root 비밀번호 |
| vault_registry_password | docker-registry htpasswd |
| vault_secloudit_admin_password | SECloudit Console 관리자 비밀번호 |

---

## 7. 변경 영향 범위

### 선행 조건
- k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 완료 상태)
- Harbor 이미지 로드 완료 상태

### 영향 범위
- **FluentD Agent**: K8s 클러스터 상태에 영향 (DaemonSet으로 각 노드에 배포)
- **Tekton 배포 실패 시**: K8s 클러스터 상태에 영향 없음 (Namespace 격리)
- **VM 컴포넌트**: K8s 클러스터와 무관 (별도 VM에서 독립 실행)

### 롤백 전략
- podman-compose down으로 컨테이너 제거
- kubectl delete로 in-cluster 리소스 제거

---

## 8. 미확인 항목

# TODO: 확인 전까지 임의 결정 금지

| 항목 | 상태 |
|---|---|
| Image Registry: docker-registry vs Harbor 현장별 선택 기준 | 미확인 |
| SE 노드와 Image Registry 노드 통합 여부 | 미확인 |
| FluentD Agent FLUENT_FORWARD_HOST 값 (Logging VM IP) | 미확인 |
| FluentD CLUSTER_DIVIDE_VALUE (클러스터 구분자) | 미확인 |
| httpd https proxy 인증서 경로 및 설정값 | 미확인 |
| Tekton manifest의 이미지 레지스트리 주소 (SEClouditREG → 실제 주소로 치환 필요) | 미확인 |

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-16 | 초안 작성 — instruction.md 기반 8개 섹션 |
