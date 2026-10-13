# SimpleToast (vendored)

Copy of [lukacs-m/SimpleToast](https://github.com/lukacs-m/SimpleToast) at tag 0.1.6, kept as a local
package because the published versions do not compile with Swift 6.4 / Xcode 27
(`variable 'self.onTap' used before being initialized` in `SimpleToastModifier.init`).

Only change: `SimpleToastModifier.init` assigns `_tapToDismiss = State(initialValue:)` instead of the
wrapped value. Remove this folder and restore the remote dependency once upstream ships a fix.
