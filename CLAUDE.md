# claude-statusline

Claude Code 상태줄 스크립트 하나입니다. `statusline.sh` 가 stdin 으로 JSON 을 받아 한두 줄을 출력합니다.

## 명령

```bash
bash -n statusline.sh                                    # 문법 확인
COLUMNS=69 ./statusline.sh < sample.json                 # 폭을 바꿔 가며 출력 확인
CLAUDE_CONFIG_DIR=$(mktemp -d) ./install.sh              # 실제 ~/.claude 를 안 건드리고 설치 시험
```

`sample.json` 은 저장소에 없습니다. 상태줄 입력을 한 번 덤프해서 씁니다.

## 레이아웃

- `statusline.sh` — 본체. 설정은 env 또는 `~/.config/claude-statusline/config`
- `config.example` — 설정 예시
- `install.sh` — 스크립트를 `~/.claude/claude-statusline/` 에 복사하고 settings.json 의 statusLine 을 병합
- `.claude-plugin/`, `commands/install.md` — 플러그인 배포(`/claude-statusline:install` 이 install.sh 를 부른다)
- `README.md` — 설치와 설정(영어, 받는 사람용)
