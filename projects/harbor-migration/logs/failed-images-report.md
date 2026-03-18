# Harbor 마이그레이션 실패 이미지 상세 보고서

생성 시각: 2026-03-18 08:35:37

---

## 요약

| 구분 | 건수 | 비율 |
|------|------|------|
| 전체 대상 | 1,207 | 100% |
| 성공 | 868 | 71.9% |
| Pull 실패 | 102 | 8.5% |
| Push 실패 | 20 | 1.7% |
| 기타 (스킵 등) | 217 | 18.0% |

---

## 1. Pull 실패 목록 (102건)

소스 Harbor(harbor.innogrid.com)에서 이미지를 가져오지 못한 경우

### 실패 원인 분석
- 이미지가 삭제되었거나 존재하지 않음
- 태그가 변경되었거나 만료됨
- 소스 Harbor 접근 권한 문제
- 네트워크 타임아웃

### 상세 목록


```
harbor.innogrid.com/devops-backend/devopsit-stage:20250929-193546-4a3330
harbor.innogrid.com/devops-backend/devopsit-dev:20250912-180936-4efcbe
harbor.innogrid.com/devops-backend/devopsit-dev:20250912-180510-4efcbe
harbor.innogrid.com/devops-backend/devopsit-dev:20250912-172154-c02dd7
harbor.innogrid.com/devops-backend/devopsit-dev:20250910-173923-c5e1e1
harbor.innogrid.com/devops-backend/devopsit-dev:20250821-181724-684ad5
harbor.innogrid.com/devops-backend/devopsit-dev:20250805-173830-744f79
harbor.innogrid.com/devops-backend/paas1159:latest
harbor.innogrid.com/devops-backend/development-postgresql:latest
harbor.innogrid.com/devops-backend/development:latest
harbor.innogrid.com/devops-backend/development:0.9.1
harbor.innogrid.com/devops-frontend/ic3:latest
harbor.innogrid.com/devops-frontend/ic3:test
harbor.innogrid.com/devops-frontend/devopsit:latest
harbor.innogrid.com/devops-frontend/devopsit:k-water-v1.0
harbor.innogrid.com/devops-frontend/devopsit:v1.7.0
harbor.innogrid.com/devops-frontend/devopsit:v1.6.0
harbor.innogrid.com/devops-frontend/devopsit:v1.5.0
harbor.innogrid.com/devops-frontend/devopsit-test:latest-test1
harbor.innogrid.com/devops-frontend/test:latest
harbor.innogrid.com/devops-frontend/dev:latest
harbor.innogrid.com/devops-frontend/dev:dev
harbor.innogrid.com/devops-frontend/dev:3-9a7f440
harbor.innogrid.com/devops-frontend/dev:1.0.2
harbor.innogrid.com/devops-frontend/dev:73-b93b52e
harbor.innogrid.com/devops-frontend/dev:72-b93b52e
harbor.innogrid.com/devops-frontend/dev:71-b93b52e
harbor.innogrid.com/devops-frontend/dev:68-b93b52e
harbor.innogrid.com/devops-frontend/dev:67-b93b52e
harbor.innogrid.com/devops-frontend/dev:66-b93b52e
harbor.innogrid.com/devops-frontend/dev:65-b93b52e
harbor.innogrid.com/devops-frontend/dev:64-b93b52e
harbor.innogrid.com/devops-frontend/dev:63-b93b52e
harbor.innogrid.com/devops-frontend/dev:62-b93b52e
harbor.innogrid.com/devops-frontend/dev:2-07620c0
harbor.innogrid.com/devops-frontend/dev:1-07620c0
harbor.innogrid.com/devops-frontend/dev:52-07620c0
harbor.innogrid.com/devops-frontend-pipeline-test/devopsit-test:test-0619
harbor.innogrid.com/dns/dns-agent:latest
harbor.innogrid.com/kafka/secloudit-alert-module:v2.5
harbor.innogrid.com/kalee-test/victorialogs-stats-collector:latest
harbor.innogrid.com/kalee-test/system-event-module:v0.16
harbor.innogrid.com/kimkyungmin/blog-app:latest
harbor.innogrid.com/kimkyungmin/predever:f143d028
harbor.innogrid.com/nginxinc/nginx-unprivileged:stable
harbor.innogrid.com/secloudit/jxgo:v2.2.3
harbor.innogrid.com/secloudit/site-seoul-v2.0:seoul-v1.5.204
harbor.innogrid.com/secloudit/site-seoul-v2.0:latest
harbor.innogrid.com/secloudit/site-kcs-v2.0.3:kcs-v1.5.204
harbor.innogrid.com/secloudit/site-kcs-v2.0.3:latest
harbor.innogrid.com/secloudit/site-posco-academy:latest
harbor.innogrid.com/secloudit/site-hwabul-saas-2.0:latest
harbor.innogrid.com/secloudit/site-edims-v1.5:latest
harbor.innogrid.com/secloudit/site-kcs-v1.5:2024-12-06-loggoupdate
harbor.innogrid.com/secloudit/site-kcs-v1.5:latest
harbor.innogrid.com/secloudit/release-secloudit-1.5:latest
harbor.innogrid.com/secloudit/master:2.0.4
harbor.innogrid.com/secloudit/master:latest
harbor.innogrid.com/secloudit-2.2-dev/jxgo:v2.2.1
harbor.innogrid.com/secloudit-2.2-dev/portal:3de79f1a
harbor.innogrid.com/secloudit-2.2-dev/portal:v2.2.1
harbor.innogrid.com/secloudit-2.2-dev/gateway-service:v2.2.3
harbor.innogrid.com/secloudit-2.2-dev/gateway-service:v2.2.1
harbor.innogrid.com/secloudit-2.2-dev/gateway-service:12
harbor.innogrid.com/secloudit-2.2-dev/api-service:v2.2.3
harbor.innogrid.com/secloudit-2.2-dev/api-service:v2.2.1
harbor.innogrid.com/secloudit-2.2-dev/api-service:18
harbor.innogrid.com/secloudit-java/keycloak:secloudit-v2.2.2-providers
harbor.innogrid.com/secloudit-java/keycloak:v2.2.1
harbor.innogrid.com/secloudit-java/keycloak:secloudit-v2.2
harbor.innogrid.com/secloudit-java/secloudit-k8s-service:30
harbor.innogrid.com/secloudit-java/secloudit-k8s-service:25
harbor.innogrid.com/secloudit-java/secloudit-k8s-service:v2.1
harbor.innogrid.com/secloudit-java/secloudit-k8s-service:6
harbor.innogrid.com/secloudit-java/secloudit-k8s-service:5
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:44
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:42
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:33
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:25
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:v2.1
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:15
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:8
harbor.innogrid.com/secloudit-java/secloudit-jxgo-service:7
harbor.innogrid.com/secloudit-java/secloudit-go-service:7
harbor.innogrid.com/secloudit-java/secloudit-go-service:6
harbor.innogrid.com/secloudit-java/legacy-go-service:3
harbor.innogrid.com/secloudit-java/api-service:72
harbor.innogrid.com/secloudit-java/api-service:v2.1
harbor.innogrid.com/secloudit-java/gateway-service:79
harbor.innogrid.com/secloudit-java/gateway-service:v2.1
harbor.innogrid.com/secloudit-ui/site-seoul-v2.0:latest
harbor.innogrid.com/secloudit-ui/site-kcs-v2.0.3:latest
harbor.innogrid.com/secloudit-ui/site-posco-academy:latest
harbor.innogrid.com/secloudit-ui/site-hwabul-saas-2.0:latest
harbor.innogrid.com/secloudit-ui/site-edims-v1.5:latest
harbor.innogrid.com/secloudit-ui/site-kcs-v1.5:latest
harbor.innogrid.com/secloudit-ui/release-secloudit-1.5:latest
harbor.innogrid.com/secloudit-ui/master:latest
harbor.innogrid.com/testimage/git-web-test:test3
harbor.innogrid.com/testimage/git-web-test:test2
harbor.innogrid.com/testimage/git-web-test:test1
harbor.innogrid.com/testimage/git-web-test:test
```

---

## 2. Push 실패 목록 (20건)

대상 Harbor(harbor.sre.local)로 이미지를 업로드하지 못한 경우

### 실패 원인 분석
- 대형 이미지 업로드 타임아웃
- 네트워크 불안정
- Harbor 스토리지 일시적 오류
- Docker 클라이언트 타임아웃

### 상세 목록


```
harbor.sre.local/ai-platform/kwater-backend:v1-gpu
harbor.sre.local/ai-platform/drift-backend:latest
harbor.sre.local/ai-platform/opensearch-dashboards:3.5.0
harbor.sre.local/ai-platform/automl-ray:2.52.1
harbor.sre.local/devops-backend/devopsit-dev:20250924-174201-97a027
harbor.sre.local/devops-backend/devopsit-dev:20250804-182641-17d375
harbor.sre.local/devops-frontend-pipeline-test/devopsit-test:15-9a7f440
harbor.sre.local/devops-util/unitycatalog-ui:v0.3.1
harbor.sre.local/devops-util/unitycatalog-server:v0.3.1
harbor.sre.local/devops-util/jenkins-controller:2.528.2-jdk21
harbor.sre.local/devops-util/jenkins-controller:2.516.3-jdk21
harbor.sre.local/devops-util/jenkins-inbound-agent:3355.v388858a_47b_33-3-jdk21
harbor.sre.local/devops-util/jenkins-inbound-agent:3345.v03dee9b_f88fc-1-jdk21
harbor.sre.local/devops-util/jenkins-home:2.499-jdk21
harbor.sre.local/gitlab/gitlab-ce:15.11.3
harbor.sre.local/kalee-test/kasmweb-ubuntu-focal-dind:1.14.0-rolling
harbor.sre.local/ray-torch/ray-torch:latest
harbor.sre.local/secloudit/portal:latest-ci-test
harbor.sre.local/secloudit-2.2-dev/portal:3e9af838-44
harbor.sre.local/secloudit-ui/master:629995c5-18728
```

---

## 3. 프로젝트별 실패 분포


### Pull 실패 프로젝트별 집계
```
     26 devops-frontend
     23 secloudit-java
     13 secloudit
     11 devops-backend
      9 secloudit-2.2-dev
      8 secloudit-ui
      4 testimage
      2 kimkyungmin
      2 kalee-test
      1 nginxinc
      1 kafka
      1 dns
      1 devops-frontend-pipeline-test
```

### Push 실패 프로젝트별 집계
```
      7 devops-util
      4 ai-platform
      2 devops-backend
      1 secloudit-ui
      1 secloudit-2.2-dev
      1 secloudit
      1 ray-torch
      1 kalee-test
      1 gitlab
      1 devops-frontend-pipeline-test
```

---

## 4. 후속 조치 권장사항

### Pull 실패 이미지
1. **소스 Harbor 확인**: 해당 이미지가 실제로 존재하는지 확인
2. **태그 확인**: 태그가 변경되었거나 삭제되었는지 확인
3. **권한 확인**: sre-user 계정의 접근 권한 확인
4. **제외 처리**: 더 이상 필요 없는 이미지는 마이그레이션 목록에서 제외

### Push 실패 이미지
1. **재시도**: 네트워크 안정화 후 개별 재시도
2. **분할 전송**: 대형 이미지는 별도 시간대에 전송
3. **타임아웃 조정**: Docker 클라이언트 타임아웃 설정 증가
4. **Harbor 상태 확인**: 대상 Harbor 스토리지 및 상태 점검

---

## 5. 재시도 명령어

### 전체 재시도 (resume 기능 사용)
```bash
bash scripts/harbor-migrate.sh
```

### 특정 프로젝트만 재시도
```bash
bash scripts/harbor-migrate.sh --project <프로젝트명>
```

### 개별 이미지 수동 마이그레이션
```bash
docker pull harbor.innogrid.com/<project>/<repo>:<tag>
docker tag harbor.innogrid.com/<project>/<repo>:<tag> harbor.sre.local/<project>/<repo>:<tag>
docker push harbor.sre.local/<project>/<repo>:<tag>
docker rmi harbor.innogrid.com/<project>/<repo>:<tag> harbor.sre.local/<project>/<repo>:<tag>
```

