# KijaniKiosk Capstone Test Plan

| Test | Expected result | Evidence |
|---|---|---|
| Application unit tests | All tests pass | npm test |
| Lint | No lint errors | npm run lint |
| Build | Distribution artifacts created | npm run build |
| Staging rollout | Two available replicas | kubectl rollout status |
| Staging health | HTTP 200 and status ok | /health smoke test |
| Staging isolation | Deployment exists in kijani-staging | kubectl get deployment |
| Environment separation | Staging DB_HOST differs from production | ConfigMap inspection |
| Self-healing | Deleted pod is recreated | Pod deletion evidence |
| Production approval | Approval required after staging smoke test | Jenkins console |
| Rollback | Previous release can be restored | Deployment/incident evidence |
