# Bubble Runtime downgrade rejection

Date: 2026-09-10

## Scope

`BUB-P7-01`の残作業だったversion順序によるdowngrade拒否をhost fixtureで確認した。実機の
active Runtime、設定、ROM、BIOS、save/stateは使用・変更していない。

## Test

一時rootへRuntime `1.1.0`を正常適用してhealth確定後、同じEd25519鍵で署名し、source versionも
`1.1.0`に一致するtarget `1.0.0` packageを作成した。署名・source照合だけなら受理される条件で、
SemVer順序だけが拒否理由になるfixtureである。

updaterは次で拒否した。

```text
runtime downgrade is forbidden: installed=1.1.0 requested=1.0.0
```

拒否後はinstalled `VERSION`、managed payload、user-owned設定が不変で、pending requestも作成
されなかった。同じfixture内で正常な`1.0.0 -> 1.1.0`、`1.1.0 -> 1.2.0`、FE health確定、
health未確定bootからのrollback 2回も再検証した。

```text
bubble_runtime_update=result-ok signature=ed25519 downgrade=rejected rollback=2 persistence=ok
```

boot/kernel/DTB/module/SystemはRuntime Updateの対象外を維持する。他のplumOSシリーズと同様に、
これらは検証済みfull SD imageのwrite/readbackとknown-good SD recoveryで更新する。
