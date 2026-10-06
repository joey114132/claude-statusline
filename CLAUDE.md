# claude-statusline

Claude Code 상태줄 스크립트 하나입니다. `statusline.sh` 가 stdin 으로 JSON 을 받아 한두 줄을 출력합니다.

## 명령

```bash
bash -n statusline.sh                                    # 문법 확인
COLUMNS=69 ./statusline.sh < sample.json                 # 폭을 바꿔 가며 출력 확인
```

`sample.json` 은 저장소에 없습니다. 상태줄 입력을 한 번 덤프해서 씁니다.

## 레이아웃

- `statusline.sh` — 본체. 설정은 env 또는 `~/.config/claude-statusline/config`
- `config.example` — 설정 예시
- `README.md` — 설치와 설정(영어, 받는 사람용)
