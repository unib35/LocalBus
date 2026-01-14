---
allowed-tools: Read, Write, Glob, Grep
argument-hint: <기능 설명>
description: TDD 테스트 계획 수립 및 plan.md 생성
---

# TDD Plan

## Task

다음 기능에 대한 TDD 테스트 계획을 수립하고 `plan.md` 파일을 생성하세요.

**기능 설명**: $ARGUMENTS

## 계획 수립 절차

1. **기능 분석**: 요구사항을 작은 단위로 분해
2. **테스트 케이스 도출**: 각 단위별 테스트 케이스 작성
3. **우선순위 결정**: 구현 순서 결정 (간단한 것부터)
4. **plan.md 생성**: 체크리스트 형식으로 작성

## plan.md 형식

```markdown
# TDD Plan: [기능명]

## 개요
[기능 설명]

## 테스트 계획

### 1. [카테고리명]
- [ ] `testMethodName1` - 설명
- [ ] `testMethodName2` - 설명

### 2. [카테고리명]
- [ ] `testMethodName3` - 설명

## 구현 노트
[특이사항, 의존성 등]
```

## 테스트 네이밍 규칙 (Swift/XCTest)

- `test` 접두어 필수
- 카멜케이스 사용
- 행동을 설명하는 이름
- 예: `testFindNextBusReturnsNilWhenNoUpcomingBus`

## 우선순위 원칙

1. 가장 간단한 케이스부터 (happy path)
2. 경계 조건
3. 예외 케이스
4. 통합 테스트

plan.md 파일을 프로젝트 루트에 생성하세요.
