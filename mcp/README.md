# MCP 설정 (전역 전용)

이 폴더는 **전역 디렉토리에만 존재**하며, 각 프로젝트로 복사되지 않는다.
프로젝트에서 MCP 서버가 필요하면 이 전역 설정을 **참조**한다.

## 구조
- `.mcp.json` — 공통 MCP 서버 정의. 새 서버는 `mcpServers` 객체에 추가한다.

## 등록된 서버
| 이름 | 종류 | URL | 인증 |
|------|------|-----|------|
| `github` | 원격(http) | https://api.githubcopilot.com/mcp/ | OAuth (최초 1회 `/mcp`) |
| `notion` | 원격(http) | https://mcp.notion.com/mcp | OAuth (토큰 방식 미지원) |

> 원격 서버라 **토큰을 파일에 저장하지 않는다.** 인증은 아래 OAuth 절차로 한 번만 하면 된다.

## 프로젝트에서 참조하는 법
프로젝트에서 전역 MCP 설정을 쓰려면 다음 중 하나를 사용한다.

1. **CLI에 전역 설정 지정** (권장)
   ```bash
   # <하네스경로> = 이 저장소를 클론한 위치(예: ~/harness)
   claude --mcp-config <하네스경로>/mcp/.mcp.json
   ```

2. **사용자 스코프로 등록** (모든 프로젝트에서 플래그 없이 자동 사용)
   ```bash
   claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --scope user
   claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user
   ```

3. **프로젝트 .mcp.json 에서 전역 항목 복붙**
   필요한 서버 정의만 전역 `.mcp.json`에서 가져와 프로젝트 `.mcp.json`에 넣는다.

## 최초 인증 (OAuth)
1. 위 방법으로 서버를 연결한 상태에서 Claude Code 실행
2. `/mcp` 입력 → `github`, `notion` 각각 선택 → **Authenticate**
3. 브라우저가 열리면 해당 계정으로 로그인·권한 승인
4. 완료되면 서버 상태가 `connected` 로 표시된다

> Gmail 은 Google 공식 MCP 가 없어 현재 제외. 필요 시 커뮤니티 서버 + Google Cloud OAuth 자격증명으로 별도 설정.

## 새 MCP 서버 추가 예시
```json
{
  "mcpServers": {
    "remote-server": {
      "type": "http",
      "url": "https://example.com/mcp"
    },
    "local-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path"],
      "env": { "SOME_TOKEN": "${SOME_TOKEN}" }
    }
  }
}
```
> 로컬 서버에서 토큰이 필요하면 값을 직접 쓰지 말고 `${ENV_VAR}` 로 환경변수를 참조한다.
