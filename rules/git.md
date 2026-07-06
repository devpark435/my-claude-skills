# Git 상시 룰 (전 프로젝트 공통)

회사·개인 구분 없이 모든 레포에 동일 적용.

## 커밋 — AI 흔적 절대 금지

커밋/PR에 AI 도구 표시 금지:

- ❌ `Co-Authored-By: Claude *` 트레일러
- ❌ `🤖 Generated with [Claude Code]` 푸터
- ❌ `Signed-off-by` / `Reviewed-by` 자동 트레일러
- ❌ 커밋 본문·PR 본문(`gh pr create --body`) 내 "AI" / "Claude" / "Generated" 표기

## 커밋 양식

```
<type>(<scope>): <subject>        # 50자 이내, 한글 OK

[<영역 또는 파일명>]
- <변경 내용>

[<다른 영역>]
- <변경 내용>
```

- types: `feat` `fix` `chore` `refactor` `docs` `test` `perf` `style`
- scope 소문자. 프로젝트별 scope 목록은 각 레포 `.gitmessage` 또는 CLAUDE.md 참조
- `[영역]` 블록은 변경이 여러 영역 걸칠 때 — 단일 변경이면 subject+짧은 본문으로 충분
- 본문은 WHAT보다 WHY 중심. 커밋 1개 = 논리 변경 1개

## git 금지

- ❌ `--no-verify` 커밋 (훅 우회)
- ❌ push된 커밋 amend
- ❌ 보호 브랜치(main/dev 등) 직접 push·강제 push
- ❌ 사용자 명시 지시 없이 새 브랜치 분기 — 현재 브랜치에서 작업

## git worktree 생성 시

- **분기 기준 = 항상 현재 HEAD** (`git worktree add ../wt -b <branch>` 기본 동작). `origin/main` 등 원격 기준으로 따지 말 것 — 로컬 미push 커밋이 워크트리에서 빠짐.

### ignored 파일 복사 필수

CLAUDE.md·`.env`류가 gitignore된 레포는 워크트리에 안 따라옴. 생성 직후:

```bash
# 원본 레포 루트에서 (경로는 프로젝트에 맞게)
cp CLAUDE.md <worktree>/ 2>/dev/null
cp .env <worktree>/ 2>/dev/null; cp assets/.env <worktree>/assets/ 2>/dev/null
cp .gitmessage <worktree>/ 2>/dev/null
```

복사 없으면: 프로젝트 룰 누락 + 빌드/테스트 실패(.env 없음). `~/.claude/rules/` 룰은 홈 경로라 워크트리에서도 자동 적용됨.
