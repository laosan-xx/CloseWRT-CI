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
# openwrt-24.10 的 Makefile 没有 PKG_BUILD_DEPENDS:=python-setuptools/host，
# 只有源行存在时才补充 CONFIG/BUILD 依赖，避免断言失配直接中断流程。
if ! grep -Fqx 'PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_python3-smbus' "$I2C_MAKEFILE" \
	&& grep -Fqx 'PKG_BUILD_DEPENDS:=python-setuptools/host' "$I2C_MAKEFILE"; then
	# Keep the Make expressions literal; they are intentionally not shell-expanded.
	# shellcheck disable=SC2016
	sed -i 's/^PKG_BUILD_DEPENDS:=python-setuptools\/host$/PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_python3-smbus\nPKG_BUILD_DEPENDS:=PACKAGE_python3-smbus:python-setuptools\/host/' \
		"$I2C_MAKEFILE"
fi

# Keep the Make expressions literal; they are intentionally not shell-expanded.
# shellcheck disable=SC2016
sed -i \
	-e 's/^\t$(call Py3Build\/Compile)$/\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build\/Compile))/' \
	-e 's/^\t$(call Py3Build\/Install)$/\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build\/Install))/' \
	-e 's/^  DEPENDS:=+libi2c +python3-light$/  DEPENDS:=+libi2c +PACKAGE_python3-smbus:python3-light/' \
	"$I2C_MAKEFILE"

# 只断言真正起作用的改动，避免依赖上游可能不存在的行。
grep -Fqx '  DEPENDS:=+libi2c +PACKAGE_python3-smbus:python3-light' "$I2C_MAKEFILE"
grep -Fqx $'\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build/Compile))' "$I2C_MAKEFILE"
grep -Fqx $'\t$(if $(CONFIG_PACKAGE_python3-smbus),$(call Py3Build/Install))' "$I2C_MAKEFILE"
