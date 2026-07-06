# 팜페이 Figma 컴포넌트 라이브러리 — node-id 인덱스

> fileKey `bwyprjbNmhtD0lEz2ydvmk` · "Design System" 페이지 `1974:6052`
> 재사용 컴포넌트 마스터/변형 세트. 화면 안 컴포넌트를 단독 조회·구현할 때 여기서 node-id를 찾는다.
> figma MCP: `get_design_context` / `get_screenshot`(단독은 `contentsOnly: true` 권장).
>
> ⚠️ **스냅샷/비망라적.** 컴포넌트도 추가·변경된다. 여기 없으면 페이지 `1974:6052`를 `get_metadata`로 라이브 탐색.
> Figma는 컴포넌트셋을 frame(셋) + symbol(변형)로 표현. icons는 별도(아래).

## 컴포넌트 세트 (변형 묶음) — 화면 빈출 순

| 세트 | node-id | 변형 수 |
|------|---------|--------|
| card/order-state | `4495:5499` | 7 (주문상태별, 아래 표) |
| card/store | `3761:8576` | 2 |
| card/banner | `4495:12677` | 3 |
| quickmenu | `5148:22981` (DS) / `4078:13250` | 2 / 2 |
| button/cta | `691:343` | 11 |
| heading | `3719:12321` | 3 |
| progressBar/challenge | `3796:14194` | 3 |
| progressBar/prescription | `3761:8681` | 4 (주문 진행 4단계) |
| tabbar | `3694:9939` | 4 (pharmacy/home/medication/my) |
| navigation/top | `940:1628` | 5 |
| searchbar | `4977:49659` | 2 |
| input | `942:1279` | 5 |
| input/otp | `4632:31152` | 2 |
| accordion | `3937:21354` | 4 |
| accordion/fill | `3709:7173` | 6 |
| accordion/nofill | `3796:13014` | 2 |
| medicine | `5165:10904` | 2 |
| medicine/accordion | `3796:12477` | 3 |
| medicine/text | `3719:8810` | 4 |
| medicine/image | `3688:9183` | 4 |
| medicine/detail | `4189:19177` | 2 |
| card/dose | `3747:7797` | 2 |
| card/point__list__item | `3937:21230` | 4 |
| coupon__item | `3948:14758` | 2 |
| coupon/group | `3948:13902` | 2 |
| notification__item | `4593:35173` | 7 |
| pharmacy_list__item | `5149:28422` | 2 |
| pharmacy_list__item__state | `4577:13265` | 2 |
| product | `4632:31400` | 2 |
| popup | `4632:28137` | 2 |
| status | `4852:13205` | 5 |
| subtitle | `3888:21788` | 4 |
| badge/time | `5086:22905` | 4 (morning/lunch/afternoon/night) |

**버튼/태그/탭/입력 보조 세트**: button/chip `4058:13618` · button/segmented `3735:8021` · button/radio `4977:47209` · button/round `3735:9522` · button/icon `3796:14172` · button/favorite `3761:1764` · button/text `3796:14171` · chip `4484:13541` · chip__item `3735:8379` · tab/large `3735:8280` · tab/small `5162:29065` · tab__item `3702:12455` · tag `3686:8726` · tag/auth `4593:40478` · tag/number `3948:13281` · tag/round `4626:27528` · checkbox `982:1640` · toggle `1502:3096` · switch `5094:11667` · time `3796:12698` · check_circle `940:657` · list__item `3943:5975` · pay-grid-item `4977:47597` · icc(아이콘 사이즈 래퍼) `3719:9232` · flag `3719:9255`

## card/order-state 변형 (주문 상태별) — 세트 `4495:5499`

홈 주문상태 화면들의 핵심 카드. variant별 node-id:

| variant | node-id | 의미(추정) |
|---------|---------|-----------|
| review | `4495:5569` | 확인중 |
| approved | `3796:16752` | 승인·결제대기 |
| making | `4495:5500` | 조제중/대체조제 |
| completed | `4495:5526` | 수령 완료/가능 |
| visiting | `4489:17267` | 방문(중) |
| visited | `4557:41577` | 방문 후 |
| need | `5082:11154` | 액션 요청(대체조제 동의 등) |

## 단일(non-set) 마스터 — 주요

carousel `3796:18200` · card/challenge-home `4699:12890` · card/challenge `3791:9974` · card/point `4587:32453` · card/small `3791:12401` · card/add `4977:47300` · card/empty `3796:14209` · app/header `4732:2305` · statusBar `4661:10318` · Home Indicator `3719:7333` · divider `4583:24378` · indicator `3702:13121` · button/floating `4577:7129` · button/text-link `4632:27810` · toast `4227:18921` · toast/primary `4593:36010` · bottomsheet `4577:11754` · profile `4557:41744` · coupon/summary `4577:12760` · map/marker `4775:31476` · time_setting `3796:12765` · menu/list `4632:31282` · rx-card `4735:2395` · pay `3906:14249`

## 위치 주의 — Section_* (화면 레이아웃 프레임)

화면의 큰 섹션 묶음은 DS 마스터가 아니라 예시 화면(example_pages) 안 레이아웃 프레임인 경우가 있다:

- **Section_medication**: DS 직속 마스터 `5160:28633` 존재 + 인스턴스 example_pages 안.
- **Section_recommend** (`4632:32118`, `4632:32133`) / **Section_favorite** (`4632:32130`): 이 서브트리에선 example_pages 안에서만 발견 — 독립 마스터가 아니라 화면 구성 프레임일 가능성. 단독 필요 시 해당 화면 `get_metadata`로 node-id 확보 후 조회.

## 아이콘

`section:icons` 안에 `icon_element/*` 약 **937개**(arrow/outline/fill 카테고리). 개별 인덱스는 비현실적 → 필요한 아이콘은 `1974:6052`(또는 icons 섹션)에서 `get_metadata`로 이름 검색. 사이즈 래퍼는 세트 `icc` `3719:9232`(12~50px).

## 간편모드 (Design System 내)

⚠️ "화면" 페이지엔 간편모드 섹션이 없지만, **Design System 페이지엔 `간편모드` 섹션 `5174:46315`이 존재**한다 (quickmenu `easy-mode` 변형 `5174:46274` 연관). 간편모드 화면군이 필요하면 이 섹션을 `get_metadata`로 탐색. (현재 화면 인덱스 범위 밖)
