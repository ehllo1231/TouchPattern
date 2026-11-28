# RINNER (린네르)

먼저 본 위치와 리듬을 기억했다가 그대로 재현하는 2×2 리듬게임 MVP입니다. 음악은 멈추거나 되감기지 않고, **시범 → 재현** 구간이 곡 안에서 번갈아 이어집니다. 플레이어와 PC용 채보 메이커가 같은 프로젝트에 들어 있습니다.

스택은 **Godot 4.7.2 Standard + GDScript**입니다. .NET 버전은 필요하지 않습니다.

[타이틀](docs/screenshots/title.png) · [곡 선택](docs/screenshots/song-select.png) · [보라 시범](docs/screenshots/player.png) · [청록 플레이](docs/screenshots/response.png) · [타일 판정](docs/screenshots/judgments.png) · [채보 메이커](docs/screenshots/chart-maker.png)

## 다른 PC에서 개발

Git이 설치된 PC에서 저장소를 복제합니다.

```sh
git clone https://github.com/ehllo1231/TouchPattern.git
cd TouchPattern
```

Windows에서는 `start-game.cmd` 또는 `start-chart-maker.cmd`를 실행하면 필요한 Godot 엔진을 자동으로 준비합니다. 에디터로 개발하려면 준비된 `.tools/Godot_v4.7.2-stable_win64.exe`로 `project.godot`를 여세요. 두 곡의 채보·음원과 폰트는 저장소에 포함되어 있습니다. 엔진·내보내기 템플릿(`.tools/`), 가져오기 캐시(`.godot/`), APK 등 빌드 결과(`builds/`)는 Git에서 제외하고 PC마다 다시 만듭니다. Android 빌드는 아래 안내대로 SDK/JDK를 각 PC에 설정해야 합니다.

이미 복제한 PC에서는 작업 전에 `git pull --ff-only`로 최신 변경을 받고, 작업을 마치면 커밋·푸시합니다. 직접 만든 곡은 저장 창에서 저장소 안의 `Songs/` 같은 폴더를 선택해 채보 JSON과 음원을 함께 커밋하세요. 기존 `user://charts/`에 저장한 두 기본 곡의 수정본은 아래 명령으로 최신 채보·음원을 `assets/`에 반영한 뒤 함께 커밋할 수 있습니다. 원본 저장 채보는 유지되며 음원 경로만 다른 PC에서도 쓸 수 있는 상대 경로로 바뀝니다.

```bat
.tools\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/sync_songs.gd
```

이전에 작업하던 PC에 `user://charts/` 저장본이 남아 있으면 게임은 그 저장본을 우선 사용합니다. 다른 PC에서 수정한 채보를 이어서 편집할 때는 메이커에서 저장소의 `assets/charts/` 파일을 직접 여세요. 음량·타이밍 보정 같은 개인 설정은 PC마다 따로 저장됩니다.

## Windows에서 실행

- **게임:** `start-game.cmd` 더블클릭
- **채보 메이커:** `start-chart-maker.cmd` 더블클릭
- **GUI 에디터:** `start-gui-editor.cmd` 더블클릭

프로젝트의 `.tools`에 포터블 Godot가 준비되어 있습니다. 다른 PC에서 이 폴더 없이 시작하면 첫 실행에 공식 GitHub 릴리스에서 엔진을 다운로드하고 SHA512를 확인합니다. 시스템 설치나 PATH 변경은 하지 않습니다. 첫 실행에는 폰트와 음원을 가져오는 시간이 조금 걸립니다.

첫 설치가 중단되면 같은 실행 파일을 다시 실행하세요. 이미 받은 엔진 압축 파일의 SHA512가 공식 값과 일치하면 재사용하고, 불완전한 파일은 다시 다운로드합니다.

Godot 에디터를 직접 쓰려면 **Import → `project.godot` 선택 → F5**로 게임을 실행하세요. 일시정지 메뉴의 **메이커 ↗** 버튼은 채보 메이커를 별도 창으로 엽니다. 게임은 9:16 세로 창으로, 메이커는 기존 PC용 가로 창으로 열립니다.

엔진 경로를 직접 지정하는 실행 방법도 같습니다.

```sh
godot --headless --path . --editor --quit
godot --path .
godot --path . -- --chart-maker
godot --path . -- --gui-editor
godot --path . -- --chart /absolute/path/song.json
```

## GUI 에디터

`start-gui-editor.cmd` 또는 게임 일시정지 메뉴의 **GUI ↗**로 별도 창을 엽니다. 왼쪽에서 **시범 그리드 / 플레이 그리드**의 한 변 길이를 슬라이더나 숫자로 각각 조절하면, 오른쪽의 실제 게임 UI에 바로 반영됩니다. 2×2 칸 수와 중심 위치는 유지하며, 540×960 기준으로 180~320px를 지원합니다. 기본값은 두 그리드 모두 260px입니다.

**게임 화면 → 시범 색상**에서 **4박 / 2박 / 1박**을 고른 뒤 옆의 색상 칸을 누르면 팔레트가 열립니다. 색을 직접 고르거나 RGB·HSV 수치 또는 HEX 코드를 입력하세요. **시범** 미리보기에서는 오른쪽 위 타일을 켜 둬서 편집 중인 색과 테두리, 후광을 바로 비교할 수 있습니다. 기본색은 4박 보라 `#BB92F5`, 2박 코랄 `#F47668`, 1박 라즈베리 레드 `#D9698B`입니다.

미리보기의 **시범 / 플레이**로 활성 그리드를 바꾸고, 화면 크기 목록으로 일반·긴 세로 화면, 태블릿, 가로 화면을 확인할 수 있습니다. **편집할 화면 → 시작 화면**에서는 실제 타이틀을 미리 봅니다.

**편집할 화면 → 전환 화면**에서 4박·2박·1박 사이의 전환 방향을 선택하고 **재생**을 누르면, 다음 시범 직전 두 박과 다음 시범의 첫 박을 한 번 재생합니다. **1박 → 2박**과 **1박 → 4박**에서는 현재 패턴의 시범 1박과 플레이 1박이 예고 구간입니다. 두 패턴이 바로 이어지면 1박 시범의 첫 박에 다음 박의 색으로 경고등이 켜집니다. **시범 전 소등 간격**은 다음 시범 직전에 경고를 꺼 둘 시간입니다. 기본값인 1박이면 0.4박 점등·0.2박 유지·0.4박 소등 후 마지막 플레이 1박 동안 경고등이 꺼집니다.

**느낌표 크기**, **깜빡임 길이**(박), **깜빡임 강도**(%)를 조절하고 **재생**을 다시 눌러 확인하세요. 깜빡임 길이와 강도는 켜질 때와 꺼질 때 모두 적용됩니다. 둘 중 하나를 0으로 두면 일정한 밝기로 켜져 있다가 소등 간격이 시작되는 순간 꺼집니다. **미리보기 BPM**은 에디터의 재생 속도에만 적용되며 실제 플레이에서는 채보 BPM을 따릅니다.

**저장 / Ctrl+S**를 누르면 `assets/ui/gui_layout.tres`에 저장합니다. 실행 중인 게임 창으로 돌아오면 저장값을 다시 읽고, 다음 게임 실행과 APK 빌드에도 같은 값이 적용됩니다. **기본값으로**는 게임 화면에서 박별 색상과 두 그리드 크기(260px)를, 전환 화면에서 느낌표 크기(48px), 깜빡임 길이(0.4박), 강도(65%), 시범 전 소등 간격(1박)을 복원합니다. 게임에 반영하려면 저장하세요.

[GUI 에디터 화면](docs/screenshots/gui-editor.png) · [전환 화면 편집](docs/screenshots/transition-editor.png)

## Android APK

- **빌드:** `build-android.cmd`를 실행하면 `builds/android/RINNER-debug.apk`를 만듭니다.
- 빌드할 때 PC에 저장된 두 곡의 최신 채보·음원을 프로젝트의 포함 파일에 동기화합니다. 메이커에서 저장한 편집 내용도 다음 APK에 반영되며, 원본 저장 채보는 수정하지 않습니다.
- Android SDK와 Java SDK 경로는 Godot의 **Editor Settings → Export → Android**에서 설정합니다. 현재 PC의 기존 SDK/JDK 설정을 사용합니다.
- 첫 빌드에 내보내기 템플릿이 없으면 공식 Godot 4.7.2 템플릿을 내려받아 SHA512를 검증하고, Android 템플릿만 `.tools/export_templates`에 보관합니다.
- APK는 휴대폰 설치용 **디버그 서명 빌드**이며 ARM 32/64비트, Android 7.0 이상을 지원합니다. 곡·채보·폰트를 포함하므로 PC의 Downloads 폴더나 외부 음원 없이 플레이할 수 있습니다.
- 휴대폰으로 APK를 복사한 뒤 파일을 열어 설치합니다. 설치 앱에서 요청하면 해당 앱의 **알 수 없는 앱 설치 허용**을 켭니다.
- Android 뒤로가기는 플레이 중 일시정지/재개, 곡 선택에서는 타이틀 복귀로 동작합니다. PC 전용 채보 파일 열기·메이커 실행 메뉴는 모바일에서 숨깁니다.
- 에뮬레이터 검증용 x86_64 빌드는 별도 `Android Emulator` 프리셋을 사용합니다. 휴대폰에는 `RINNER-debug.apk`를 설치하세요.

현재 APK의 빌드·서명(v2/v3)·포함 리소스를 검증했고, APK에서 추출한 실제 게임 콘텐츠도 데스크톱에서 정상 로드했습니다. 이 PC의 Android 에뮬레이터에서는 SwiftShader의 `GL_MAX_FRAGMENT_UNIFORM_VECTORS` 오류로 화면 렌더링 검증을 완료하지 못했습니다([Godot 관련 이슈](https://github.com/godotengine/godot/issues/109550)). 실제 휴대폰에서의 플레이·입력·오디오 지연 검증은 별도로 필요합니다.

```sh
godot --headless --path . --export-debug Android builds/android/RINNER-debug.apk
```

## 플레이

1. **RINNER 타이틀**에서 화면 어디든 터치하거나 클릭합니다. 별도의 Start 버튼은 없습니다. PC에서는 Enter 또는 Space도 사용할 수 있습니다.
2. **곡 선택**에서 `The Descent Loop` 또는 `Electric Dreams` 카드를 누르면 선택한 곡을 바로 플레이합니다. 두 카드를 세로로 배치하며 BPM·길이·패턴 수는 실제 채보와 음원에서 읽습니다. PC에서는 Tab/방향키로 카드에 초점을 옮긴 뒤 Enter로 선택할 수도 있습니다. 뒤로가기 또는 Esc로 타이틀에 돌아갈 수 있습니다.
3. 일시정지·결과 메뉴의 **곡 선택으로**를 누르면 음악과 플레이어를 정리하고 곡 선택 화면으로 돌아갑니다.

현재 곡 목록에는 **The Descent Loop**, **Electric Dreams** 두 곡을 표시합니다. `user://charts/`에 각 곡의 저장 채보가 있으면 최신 편집본을 사용하고, 없으면 프로젝트에 포함한 채보·MP3를 사용합니다. 두 곡 모두 APK에 포함되므로 모바일에서도 외부 파일 없이 선택할 수 있습니다. 게임 이름을 바꾸어도 기존 TouchPattern 사용자 폴더를 유지하므로 채보·음량·타이밍 보정 설정은 그대로 사용할 수 있습니다.

| | 왼쪽 | 오른쪽 |
|---|---|---|
| 위 칸 | U / 패드 X | I / 패드 Y |
| 아래 칸 | J / 패드 A | K / 패드 B |

- **Space:** 시작 / 일시정지 / 이어서 재생
- **R:** 처음부터 다시 시작. 메이커의 플레이 테스트에서는 테스트를 시작했던 위치부터 다시 시작합니다.
- **Esc:** 일시정지 / 이어서 재생
- 아래쪽 그리드는 키보드, 게임패드, 마우스, 멀티터치로 입력할 수 있습니다.
- **입력 진동 강도**는 **소리 · 타이밍 설정**에서 0~100%로 조절합니다. 기본값은 0%(꺼짐)입니다. 켜 두면 직접 누른 타일이 Perfect, Good, OK일 때 그 버튼을 누른 게임패드나 터치한 휴대폰에서 짧게 진동합니다. 진동 세기는 기기와 드라이버의 지원 범위를 따릅니다.
- 위쪽 그리드가 빛날 때 위치와 박자를 기억하고, 아래쪽 **청록색** 그리드가 활성화되면 입력합니다. 시범의 기본색은 **4박 보라, 2박 코랄, 1박 라즈베리 레드**이며, 다른 길이는 4박 색상을 사용합니다. 한 곡에서 섞어도 BPM과 판정 기준은 동일합니다. 두 그리드는 기본 크기가 같고 GUI 에디터에서 각각 조절할 수 있으며, 타일에는 키 안내나 번호가 표시되지 않습니다. 재현 구간에는 정답 노트가 표시되지 않습니다.
- 판정은 Perfect ±50ms, Good ±100ms, OK ±150ms입니다. 노트를 놓치거나 재현 구간에서 잘못된 칸·쉼표에 입력하면 모두 Miss이며 정확도가 낮아집니다.
- 4박·2박·1박 사이의 전환을 앞두면 다음 시범 시작 전 최대 두 박 동안 시범 그리드 위의 둥근 삼각형 느낌표로 예고합니다. 4박·2박 패턴에서는 플레이 중에, 1박 패턴에서는 시범부터 예고할 수 있습니다. 경고는 다음 시범의 색을 따르며, 2박 기본 코랄의 경고등은 기존 주황빛입니다. 네온관의 중심선이 짧게 빛나고 한 번 약해졌다가, 삼각형과 느낌표 둘레에 후광이 퍼지며 점등됩니다. 시범 중 타일에는 시범 노트의 빛만 보입니다. 플레이 중에는 경고등 바로 아래 두 타일의 안쪽 윗모서리에 경고색이 은은하게 비치며 함께 깜빡입니다. 소등은 점등 애니메이션을 같은 길이로 역재생합니다.
- 판정은 입력한 **타일 안**에만 잠깐 나타납니다. PERFECT는 청록색 체크와 확산, GOOD은 하늘색 링, OK는 연한 금색 링, MISS는 분홍색 모서리로 구분합니다. 같은 타일의 새 판정은 이전 효과를 교체하며, 모든 판정은 0.44초 이내에 사라집니다.
- 상단에는 점수, 콤보, 얇은 진행 게이지와 일시정지 아이콘만 표시합니다. **다시 시작 / 채보 열기 / 메이커 / 소리·타이밍 설정**은 일시정지 메뉴에서 사용할 수 있습니다. 결과와 정확도는 곡이 끝난 뒤 메뉴에서 확인합니다.
- 마지막 패턴의 판정 유예 시간이 끝나면 입력과 점수를 확정하고, 남은 음악은 끝까지 재생한 뒤 결과를 표시합니다. 반대로 채보가 음원보다 길면 음악이 끝난 뒤 무음 상태로 시범·재현과 노트 효과음을 계속 진행합니다. 진행 게이지는 음원과 채보 중 더 긴 전체 플레이 구간을 기준으로 움직입니다. 후주나 무음 구간에서도 일시정지·재개·다시 시작할 수 있습니다.
- **타이밍 보정:** 일시정지 메뉴의 **소리 · 타이밍 설정**에서 조절합니다. 입력이 지속적으로 늦게 판정되면 + 방향으로 조정합니다. 노트 판정에 적용되며 변경 즉시 사용자 폴더에 저장됩니다.
- **상세 판정 보기:** 일시정지 메뉴의 **소리 · 타이밍 설정**에서 켭니다. 시범 그리드 바로 위에 `−23.4 ms`(빠름/EARLY), `+23.4 ms`(늦음/LATE)처럼 현재 입력의 판정 오차를 소수점 한 자리까지 표시합니다. 중앙 기준선과 작은 마커로 방향을 보여 주고 0.75초 안에 사라집니다. 새 입력은 이전 표시를 교체합니다. 기본값은 꺼짐이며 설정은 저장됩니다. 표시값은 기존 타이밍 보정이 적용된 판정 결과를 사용하며 점수·판정 기준은 바꾸지 않습니다. 매칭된 입력이 없는 MISS는 `— ms`로 표시합니다.
- **박수 소리:** 시범 노트, 재현 구간의 실제 입력, AUTO 연주에 짧은 박수가 나옵니다. 메이커에서는 **구간 듣기·연속 듣기 옆의 박수 소리**를 켜면 시범과 재현 모두에 적용됩니다. 옆의 **음량 슬라이더(0~100%)**는 음악 음량을 바꾸지 않고 박수만 실시간으로 조절합니다. 0%는 무음입니다. 플레이어에서는 일시정지 메뉴의 **소리 · 타이밍 설정 → 노트 효과음**에서 켜짐과 음량을 조절합니다. 설정은 저장되며 창에 다시 돌아오면 다른 창에서 바꾼 값도 반영됩니다. 동시치기는 한 번의 박수로 합치고, 일시정지·직접 정지·재시작 시 남은 소리를 끊습니다. 에디터의 구간이 자연스럽게 끝날 때는 마지막 박수가 마저 재생됩니다.

개발·테스트용 샘플 **First Echo**도 유지합니다. 직접 합성한 112 BPM, 약 37.5초 곡으로, 8개 패턴과 42개 정답 노트에 쉼표·엇박자·동시치기가 포함됩니다. `--chart res://assets/charts/first_echo.json`처럼 채보를 직접 지정하거나 메이커에서 플레이 테스트를 실행하면 타이틀을 거치지 않고 기존 플레이어를 엽니다.

## 채보 만들기

1. 메이커에서 **새 채보**를 누르고 곡 제목, 음원, BPM을 설정합니다. BPM은 **소수점 셋째 자리까지** 입력·표시·저장합니다(예: `116.123`, 조절 단위 `0.001`). 새 채보는 편집 중인 곡의 음원과 기본 BPM 112를 사용하므로 다른 곡이면 바꿔 주세요.
2. **첫 박자 오프셋**을 초 단위로 설정합니다. 예를 들어 첫 박자가 음원 0.3초에 있으면 `0.3`입니다.
3. 아래쪽 **패턴 미리보기**에서 편집할 패턴을 클릭하고 **시범 시작 / 길이**를 박 단위로 지정합니다. 재현 시작은 **시범 시작 + 길이**로 자동 계산됩니다. 미리보기는 U/I/J/K 네 줄과 박자 격자가 가로로 연결되어 전체 노트 흐름을 보여줍니다. 패턴은 번호와 세로 경계선으로 구분하며, 길이에 비례한 폭으로 같은 박자 간격을 유지합니다. 선택한 구간은 민트색 상단선·경계선과 배경으로 표시합니다. 휠 또는 가로 스크롤바로 이동하고 **+ 추가 / − 삭제**로 패턴을 관리합니다. 박자는 0부터 시작합니다. 시범 `4`, 길이 `4`이면 4~8박 시범, 8~12박 재현이고, 길이 `2`이면 4~6박 시범, 6~8박 재현입니다. 길이 2박 패턴은 플레이어에서 붉은색으로 표시됩니다. 긴 음원을 중간에서 끝내려면 원하는 패턴을 선택하고 **여기서 곡 종료**를 누릅니다. 해당 재현 구간 끝에 `END`가 표시되며, **페이드 아웃**에서 0~60초를 설정할 수 있습니다. 같은 버튼을 다시 누르면 종료 지점을 해제합니다. 종료로 지정한 패턴의 시범 시작·길이를 수정하면 곡 종료 지점도 새 재현 종료점으로 이동합니다.
4. 타임라인의 U/I/J/K 행을 클릭해 노트를 넣습니다. 다시 클릭하면 지워집니다. 기본 격자는 1/4박입니다. 빈칸은 쉼표이며 같은 박자에 여러 칸을 지정하면 동시치기입니다.
5. **구간 듣기**는 선택한 패턴의 시범부터 재현까지, **연속 듣기**는 선택한 패턴부터 마지막 재현 구간까지 재생합니다. 연속 듣기에서는 음악을 끊지 않고 현재 패턴의 미리보기와 타임라인을 자동으로 선택하며, 선택한 미리보기가 보이도록 스크롤합니다. 두 방식 모두 시범·재현 노트의 정확한 입력 시점(오차 0ms)에 타임라인 오른쪽 U/I/J/K 칸과 노트의 테두리가 짧게 빛납니다. 동시치기도 함께 표시되며, BPM과 첫 박자 오프셋을 반영합니다. 노트를 배치하기 전에도 들을 수 있으며, 실제 음원 끝이나 지정한 `END`에 도달하면 음악만 멈추고 남은 채보는 무음 상태로 계속 시범 재생됩니다. **정지**를 누르거나 패턴을 직접 선택·편집하면 재생이 멈춥니다. **플레이 테스트 ↗** 옆의 **선택 구간부터**를 체크하면 선택한 패턴의 시범 시작 한 박자 전부터, 해제하면 곡 처음부터 마지막 구간까지 테스트합니다. 기본값은 체크 상태입니다. 편집 중인 채보의 임시 스냅샷을 별도 플레이어에서 열며, 건너뛴 패턴은 판정에서 제외하고 R로 다시 시작해도 같은 위치부터 재시도합니다.
6. **저장 / Ctrl+S**로 JSON을 저장합니다. 새 채보는 첫 저장에서 폴더와 파일 이름을 선택하고, 이후 저장은 선택한 파일에 계속 반영합니다. 새 채보의 저장 창은 선택한 음원 폴더에서 시작합니다. 내장 음원은 프로젝트의 `Songs/` 또는 문서 폴더를 사용합니다. **다른 이름으로 / Ctrl+Shift+S**는 현재 채보 폴더에서 열리며, 새 위치를 확인한 뒤부터 그 파일을 사용합니다. 저장 후 실제 전체 경로를 화면에 표시합니다. 게임에서 **채보 열기**로 불러옵니다. 메이커는 마지막으로 열거나 저장한 채보 경로를 기억해 다음 실행 때 자동으로 다시 엽니다. 최근 파일이 이동·삭제되었으면 기본 채보로 돌아가며, `--chart`로 특정 채보를 지정한 실행은 그 파일을 우선합니다.

**BPM 자동 찾기:** 음원을 선택한 뒤 BPM 칸 옆의 버튼을 누르면 WAV·OGG·MP3의 박자를 분석해 소수점 셋째 자리(`0.001 BPM`)로 반올림한 추정값을 바로 입력합니다. 분석 진행률을 표시하며 편집도 계속할 수 있습니다. 별도 프로그램 설치나 인터넷 연결은 필요하지 않습니다. BPM 변경은 **저장 / Ctrl+S**로 저장하세요. 첫 박자 오프셋과 노트는 유지합니다.

8초 이상의 고정 BPM 음원에 적합합니다. 소수점 세 자리는 결과의 표시·입력 단위이며, 실제 측정 오차가 항상 `±0.001 BPM`이라는 뜻은 아닙니다. 반·두 배로 셀 수 있는 박자는 현재 BPM을 참고하므로, 결과가 반·두 배로 느껴지면 대략적인 BPM을 입력한 뒤 다시 분석하세요. 템포가 바뀌거나 박자가 불분명한 곡은 구간 듣기로 확인하고 직접 보정하세요. 분석 실패 시 기존 BPM을 유지하며, 분석 중 음원·채보를 바꾸거나 BPM을 직접 수정하면 이전 분석 결과는 적용하지 않습니다.

**플레이 테스트 ↗** 옆의 **AUTO**를 체크하면 PC가 정답 타이밍에 자동으로 입력하는 시범 플레이를 보여줍니다. 기본값은 해제 상태이며, **선택 구간부터** 설정도 함께 적용됩니다. AUTO 창의 상단에는 작은 AUTO 표시가 있으며 시범과 재현의 입력 칸이 빛납니다. 수동 입력은 받지 않으며 Space·Esc로 일시정지하고 R로 다시 시작할 수 있습니다. 수동 입력 타이밍 보정은 자동 연주에 적용하지 않습니다.

박수는 실험용으로 따로 분리했습니다. `assets/audio/note_sound_config.tres`에서 `sound` 참조만 바꾸면 다른 효과음으로 교체할 수 있습니다. `volume_db`는 사용자가 음량을 저장하기 전의 기본 박수 음량(현재 -12dB, 약 25%), `demo_enabled`·`input_enabled`·`preview_enabled`는 적용 범위, `combine_simultaneous`는 동시 입력 합치기, `polyphony`는 겹쳐 재생할 수 있는 수입니다. `enabled_by_default`는 저장된 사용자 설정이 없을 때의 기본값입니다. 사용자 음량은 `user://settings.cfg`의 `[note_feedback] volume_percent`에 저장합니다. 소리 재생 코드는 `scripts/core/note_sounds.gd`, 공통 음량 UI는 `scripts/ui/note_volume_control.gd`에 모았고 판정 로직과 분리되어 있습니다. 기본 음원은 직접 합성한 `assets/audio/clap.wav`이며, `python3 tools/generate_clap.py`로 외부 라이브러리 없이 재생성할 수 있습니다. 음원·설정 파일을 수정한 뒤 앱을 다시 열면 적용됩니다.

재현 구간의 정답은 시범 패턴에서 자동으로 생성됩니다. 같은 패턴을 두 번 작성할 필요가 없습니다. 시범·재현 구간이 겹치거나 노트가 범위를 벗어나면 저장 전에 오류를 표시합니다. 패턴 길이를 줄일 때 기존 노트를 자동 삭제하지 않습니다.

외부 음원은 저장할 채보 위치를 기준으로 상대 경로로 기록합니다. 곡을 옮길 때는 JSON과 음원의 상대적인 폴더 구조를 유지하세요. WAV, OGG Vorbis, MP3를 지원합니다. 마지막 박자가 음원 끝을 넘어가도 저장·미리듣기·플레이할 수 있으며, 음원 이후 구간은 무음으로 진행됩니다.

## 채보 형식 v1

```json
{
  "format_version": 1,
  "title": "My Song",
  "artist": "Artist",
  "audio": "song.wav",
  "bpm": 112,
  "offset_seconds": 0.0,
  "audio_end_beat": 12,
  "fade_out_seconds": 3.0,
  "grid": { "rows": 2, "columns": 2 },
  "phrases": [{
    "show_beat": 4,
    "response_beat": 8,
    "length_beats": 4,
    "notes": [
      { "beat": 0, "cell": 0 },
      { "beat": 1.5, "cell": 3 },
      { "beat": 3, "cell": 1 },
      { "beat": 3, "cell": 2 }
    ]
  }]
}
```

`cell`은 좌상 0, 우상 1, 좌하 2, 우하 3입니다. `notes[].beat`는 **패턴 시작 기준**이며, 시범과 재현에서 같은 간격을 유지합니다. 선택 항목인 `audio_end_beat`는 음악을 끝낼 박자이며 반드시 어떤 패턴의 재현 종료점과 일치해야 합니다. `fade_out_seconds`는 그 직전의 페이드 길이로 기본 3초, 허용 범위는 0~60초입니다. 두 항목이 없으면 원본 음원을 끝까지 재생합니다. 그리드 크기와 칸 번호는 데이터로 분리했으며, 현재 입력과 UI는 2×2를 지원합니다. 3×3 지원에는 UI·입력 확장이 필요합니다.

## 코드와 검증

- `scripts/core/touch_chart.gd`: 채보 검증, 파일 입출력, 박자 변환, 음원 경로
- `scripts/core/song_clock.gd`: 실제 오디오 재생 위치와 출력 지연을 반영하는 시계, 일시정지·재개
- `scripts/core/bpm_detector.gd`: 음원을 소리 없이 분석하는 BPM 추정기, 배경 분석·진행률·취소
- `scripts/core/rhythm_session.gd`: 시범·재현 구간과 판정
- `scripts/core/note_sounds.gd`, `note_sound_config.gd`: 교체 가능한 노트 효과음과 설정
- `scripts/ui/player_view.gd`: 플레이어
- `scripts/ui/gui_editor.gd`, `gui_layout.gd`, `assets/ui/gui_layout.tres`: 실제 화면 미리보기, 그리드 크기 편집·저장과 게임 적용
- `scripts/app.gd`, `scripts/ui/front_menu.gd`: 타이틀 → 곡 선택 → 플레이 → 곡 선택 화면 전환
- `scripts/ui/front_artwork.gd`: 보라·청록 루프 문양과 곡 카드의 벡터 아트
- `scripts/ui/song_library.gd`: 두 곡의 목록, 기존 저장 채보 우선 사용, 실제 곡 정보·음원 검증
- `tools/sync_songs.gd`: APK 빌드 전 최신 저장 채보와 음원을 프로젝트에 동기화
- `scripts/ui/game_grid.gd`, `game_tile.gdshader`: 플레이어 전용 동일 규격 그리드와 보라/청록 타일. 공용 `grid_pad.gd` 및 메이커의 표시는 유지
- `scripts/ui/tile_feedback.gd`: 타일 내부 판정, 체크·링·모서리 효과. 입력과 판정 시계에는 관여하지 않음
- `scripts/ui/game_hud.gd`, `pause_icon.gd`: 점수·콤보·진행률·일시정지
- `scripts/ui/game_backdrop.gdshader`, `stage_decor.gd`: 독립 배경과 장식 레이어. 향후 맵별 배경·조형물은 이 레이어에서 확장
- `scripts/ui/chart_maker.gd`, `pattern_timeline.gd`: 별도 채보 메이커
- `scripts/ui/pattern_strip.gd`, `pattern_thumbnail.gd`: 공통 박자 격자로 연결한 가로 패턴 미리보기와 선택
- `tools/generate_sample.py`: 외부 라이브러리 없이 샘플 음원과 채보 재생성

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script tests/run_tests.gd
godot --headless --max-fps 120 --path . --script tests/chart_saving.gd
godot --headless --max-fps 120 --path . --script tests/player_ui.gd
godot --headless --max-fps 120 --path . --script tests/gui_editor.gd
godot --headless --max-fps 120 --path . --script tests/two_beat_patterns.gd
godot --headless --max-fps 120 --path . --script tests/front_flow.gd
godot --headless --max-fps 120 --path . --script tests/bpm_precision.gd
godot --headless --max-fps 120 --path . --script tests/bpm_detection.gd
godot --headless --max-fps 120 --path . --script tests/detailed_judgment.gd
godot --headless --max-fps 120 --path . --script tests/song_outro.gd
godot --headless --max-fps 120 --path . --script tests/song_clock.gd
godot --headless --max-fps 120 --path . --script tests/note_sounds.gd
godot --display-driver headless --audio-driver WASAPI --max-fps 120 --path . --script tests/note_sounds.gd -- --verify-mixer
godot --headless --max-fps 120 --path . --script tests/playthrough.gd
godot --headless --max-fps 120 --path . --script tests/playthrough.gd -- --start-phrase 6
godot --headless --max-fps 120 --path . --script tests/playthrough.gd -- --auto-mode
godot --headless --max-fps 120 --path . --script tests/playthrough.gd -- --auto-mode --start-phrase 6
```

`run_tests.gd`는 판정 경계, 동시치기, 오입력, 채보 검증, 경로 보존, 저장·재로딩, 실제 UI와 멀티터치, 선택 패턴 시작·재시작, AUTO 타이밍과 수동 입력 차단을 확인합니다. `song_clock.gd`는 오디오 시계의 단조 증가, 시스템 시계와의 독립성, 탐색·일시정지·재시작, 음악 종료 후 판정 유예 시간을 확인합니다. `playthrough.gd`는 실제 키 입력으로 전체 곡 또는 일곱 번째 패턴부터 14개 노트를 플레이하며, `--auto-mode`를 추가하면 키 입력 없이 AUTO 재생을 확인합니다. Windows의 실제 오디오 장치로 검증하려면 `--headless` 대신 `--display-driver headless --audio-driver WASAPI`를 사용하세요. `--headless`만 사용하면 오디오 드라이버가 Dummy이므로 실제 장치의 동기화 측정에는 적합하지 않습니다.

`player_ui.gd`는 320×568부터 긴 모바일 화면, 태블릿, 가로 화면까지 7개 크기에서 레이아웃과 터치 영역을 확인합니다. 실제 터치 이벤트로 메뉴 시작·타일 입력을 실행해 마우스 에뮬레이션에 따른 이중 판정이 없는지, 일시정지가 입력과 시계를 함께 막는지, 단계 전환·판정 효과·결과·재시작이 정상인지 검사합니다. 게임 타일은 원시 멀티터치를 처리하고 에뮬레이션된 마우스 이벤트를 무시하며, 메뉴와 슬라이더는 Godot의 기본 터치 지원을 사용합니다.

`gui_editor.gd`는 슬라이더·숫자 입력의 미리보기 동기화, 입력 중 Ctrl+S 저장, 게임의 저장값 로딩과 창 복귀 시 갱신, 시작 화면·해상도 전환, 기본값 복원과 재실행을 확인합니다. 서로 다른 그리드 크기로 7개 화면 비율의 배치·터치 영역, 실제 터치 판정, 최대 크기에서 상세 판정 표시 위치도 검증합니다.

`two_beat_patterns.gd`는 4박→2박→2박→4박 전환의 경고 색상과 박자, 휴지 구간, 시범·재현 색상, HUD·장식·셰이더 반영, 일시정지·선택 구간 시작·재시작·AUTO를 확인합니다. 메이커의 재현 시작 자동 계산, 곡 종료점 연동, 노트가 있는 구간의 축소 방지와 저장·재로딩도 검증합니다.

`chart_saving.gd`는 실제 저장 대화상자의 확인 신호로 선택한 폴더·파일명에 저장되는지, 첫 저장·저장 취소·다른 이름으로·후속 덮어쓰기·최근 파일 복원 경로·음원 상대 경로를 검증합니다. 새 채보가 AppData의 임시 파일을 만들거나 덮어쓰지 않는지도 확인합니다.

`song_outro.gd`는 마지막 판정의 유예 시간, 후주의 입력 차단과 점수 고정, 일시정지·재개·재시작, 실제 오디오의 자연 종료 후 결과 표시, 지정한 페이드 종료와 무음 시범·AUTO 재현을 확인합니다.

`front_flow.gd`는 7개 화면 크기의 타이틀·두 곡 선택 배치, 화면 전체 터치, 중복 전환 방지, 각 카드와 선택한 곡의 연결, 일시정지·결과 메뉴에서 복귀, 두 번째 카드의 키보드 선택, 누락된 곡의 오류 처리를 확인합니다. 실제 Electric Dreams MP3의 마지막 3초를 재생하고 원본 채보의 모든 노트를 AUTO 판정하여 후주와 결과 화면 연결도 검증합니다.

`bpm_precision.gd`는 BPM `116.123`의 실제 입력 확정, `0.001` 단위 조절, JSON 저장·재로딩, 긴 구간의 박자/시간 변환, 미리듣기, 판정 경계와 AUTO 점수를 확인합니다. 자릿수 확장은 기존 실수형 BPM 계산과 오디오 시계를 그대로 사용하며 프레임당 계산 횟수를 늘리지 않습니다.

`bpm_detection.gd`는 소수 BPM의 합성 박자, 엇박자·역위상 스테레오·작은 음량, 포함된 WAV·MP3 곡의 분석, 실제 버튼 클릭과 비동기 입력·저장, 분석 중 수정·음원 교체·창 종료, 무음·짧은 음원·없는 파일의 실패 처리를 확인합니다.

`detailed_judgment.gd`는 실제 터치로 옵션 켜기, 설정 저장·복원, 보정 후 실제 입력의 부호·수치와 점수, 표시 위치, 재입력·페이드·일시정지·재시작, MISS 처리, 작은 화면에서의 메뉴 스크롤을 확인합니다. `scripts/ui/timing_readout.gd`는 판정 신호가 전달한 오차만 표시하는 독립 UI이며 입력이나 판정 시계를 계산하지 않습니다.

실제 렌더러로 UI를 캡처하려면 아래 명령을 사용합니다. `--phase`는 `title`(기본), `songs`, `ready`, `demo`, `response`, `judgments`, `timing`, `timing-settings`, `paused`, `finished`를 지원합니다. 출력 폴더는 자동으로 만듭니다.

```sh
godot --audio-driver Dummy --path . --script tools/capture_preview.gd -- --phase title --size 540x960 --output res://docs/screenshots/title.png
godot --audio-driver Dummy --path . --script tools/capture_preview.gd -- --phase songs --size 390x844 --output res://docs/screenshots/song-select.png
godot --audio-driver Dummy --path . --script tools/capture_preview.gd -- --phase demo --size 540x960 --output res://docs/screenshots/player.png
godot --audio-driver Dummy --path . --script tools/capture_preview.gd -- --phase judgments --size 390x844 --output res://docs/screenshots/judgments.png
```

`note_sounds.gd`는 소리 교체·음량·적용 범위·동시치기, 음량 슬라이더와 설정 보존·창 간 재적용, 수동/AUTO 입력의 중복 방지, 시범·미리보기 타이밍, 연속 듣기 경계와 마지막 박수 재생을 검증합니다. Windows에서 `--verify-mixer`를 붙인 명령은 실제 에디터의 듣기를 재생해 노트 시각과 박수 횟수를 비교하고, 실제 믹서의 박수 파형과 50% 음량에서의 진폭도 확인합니다. 이 명령은 Windows 전용이며, Dummy 드라이버의 논리 검증과 별도로 실행합니다.

현재 시계는 [Godot 공식 문서의 오디오 하드웨어 시계 동기화 방식](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html#using-the-sound-hardware-clock-to-sync)을 사용합니다. 실제 재생 위치에 마지막 믹싱 이후 시간을 더하고 출력 지연을 빼며, 스레드 간 측정 흔들림으로 시간이 뒤로 가지 않게 합니다. 음악이 끝난 뒤에는 같은 시계를 단조 증가하는 무음 타임라인으로 이어서 마지막 판정 유예 시간이나 남은 채보를 처리합니다. BPM·첫 박자 오프셋은 음원에 맞게 설정해야 하며, 곡 자체에 템포 변화가 있으면 현재의 고정 BPM 형식으로는 전 구간을 맞출 수 없습니다. 실제 스마트폰의 터치·오디오 지연과 블루투스 출력은 기기에서 별도 검증해야 합니다. 현재 APK는 직접 설치하는 테스트용이며 스토어용 AAB·릴리스 키 설정은 포함하지 않습니다.

폰트는 Noto Sans KR이며 라이선스는 `assets/fonts/OFL.txt`에 포함되어 있습니다.
