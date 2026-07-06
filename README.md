# my-claude-skills

Claude Code 개인 스킬 + 상시 룰 저장소. `~/.claude/{skills,rules}`가 이 레포로 심볼릭 링크되어 있어, 여기 커밋 = 라이브 반영.

```
skills/<skill-name>/SKILL.md   # 온디맨드 스킬 (Claude Code 표준 레이아웃)
rules/<축>.md                  # 상시 룰 — 프로젝트 CLAUDE.md가 @~/.claude/rules/<축>.md로 참조
```

## rules/ (상시 룰)

| 파일 | 적용 |
|---|---|
| `git.md` | 전 레포 공통 — 커밋 양식, AI 흔적 금지, worktree 원칙 |
| `flutter.md` | Flutter 프로젝트 — FVM, @riverpod 코드젠, Dio 원칙 |
| `react.md` | React 프로젝트 — TS strict 함정, effect setState 금지 |
| `fastapi.md` | FastAPI 프로젝트 — 씬 핸들러, 응답 봉투, async |

원칙: 룰 = "매 세션 필요 + 안 지키면 코드가 틀리는 것"만, 파일당 ~80줄 상한. 방법지식은 스킬로. 프로젝트 고유 정보는 각 프로젝트 CLAUDE.md가 우선.

## skills/ (온디맨드)

- **Flutter**: riverpod-patterns · retrofit-dio · go-router · golden-tdd · project-bootstrap · ios-simulator-qa · figma-mcp · owasp-security
- **React**: project-bootstrap · admin-patterns (사내 어드민 골격)
- **Backend**: fastapi-service-patterns
- **QA/기기**: device-qa · serve-to-phone
- **기타**: pharpay-figma-screens · meta-ads-setup

## 새 맥 셋업

```bash
git clone https://github.com/devpark435/my-claude-skills.git
ln -s $(pwd)/my-claude-skills/skills ~/.claude/skills
ln -s $(pwd)/my-claude-skills/rules ~/.claude/rules
```
