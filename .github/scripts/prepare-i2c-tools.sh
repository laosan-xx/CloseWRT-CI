#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

set -euo pipefail

I2C_MAKEFILE=feeds/packages/utils/i2c-tools/Makefile
if [ ! -f "$I2C_MAKEFILE" ]; then
	echo "i2c-tools Makefile not found; skipping!"
	exit 0
fi

# Build the Python SMBus binding only when its package is selected. The C
# tools remain available for device profiles that only install i2c-tools.
# 24.10 的 Makefile 没有 PKG_BUILD_DEPENDS:=python-setuptools/host，
# 因此这里只按 PKG_CONFIG_DEPENDS 是否已存在判断，不再以该行为前提条件。
if ! grep -Fqx 'PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_python3-smbus' "$I2C_MAKEFILE"; then
	# shellcheck disable=SC2016
	sed -i '/^PKG_BUILD_PARALLEL:=1$/a PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_python3-smbus' \
		"$I2C_MAKEFILE"
fi

# 上游若显式声明 setuptools host 依赖（新分支才有），改为按包条件依赖。
# shellcheck disable=SC2016
sed -i 's/^PKG_BUILD_DEPENDS:=python-setuptools\/host$/PKG_BUILD_DEPENDS:=PACKAGE_python3-smbus:python-setuptools\/host/' \
	"$I2C_MAKEFILE"

# Keep the Make expressions literal; they are intentionally not shell-expanded.
# shellcheck disable=SC2016
sed -i \
	-e 's/^\t$(call Py3Build\/Compile)$/\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build\/Compile))/' \
	-e 's/^\t$(call Py3Build\/Install)$/\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build\/Install))/' \
	-e 's/^  DEPENDS:=+libi2c +python3-light$/  DEPENDS:=+libi2c +PACKAGE_python3-smbus:python3-light/' \
	"$I2C_MAKEFILE"

# 断言失败必须留下可见原因，避免再出现"无输出 exit 1"。
assert_line() {
	grep -Fqx "$1" "$I2C_MAKEFILE" || {
		echo "i2c-tools patch failed, missing line: $1" >&2
		exit 1
	}
}

assert_line 'PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_python3-smbus'
assert_line '  DEPENDS:=+libi2c +PACKAGE_python3-smbus:python3-light'
assert_line $'\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build/Compile))'
assert_line $'\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build/Install))'
echo "i2c-tools has been patched!"
