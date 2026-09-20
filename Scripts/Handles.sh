#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -d "$GITHUB_WORKSPACE/wrt/package" ]; then
	PACKAGE_PATH="$GITHUB_WORKSPACE/wrt/package"
	FEEDS_PATH="$GITHUB_WORKSPACE/wrt/feeds"
	OTHER_PATH="$GITHUB_WORKSPACE/Others"
else
	PACKAGE_PATH="./package"
	FEEDS_PATH="./feeds"
	OTHER_PATH="$(pwd)/Others"
fi

#解决wan口地址与lan口冲突
HOTPLUG_IFACE_DIR="$GITHUB_WORKSPACE/wrt/files/etc/hotplug.d/iface"
mkdir -p "$HOTPLUG_IFACE_DIR"
if [ -f "$OTHER_PATH/90-autolanip" ]; then
	echo " "
	if cp -f "$OTHER_PATH/90-autolanip" "$HOTPLUG_IFACE_DIR/90-autolanip" && chmod +x "$HOTPLUG_IFACE_DIR/90-autolanip"; then
		echo "autolanip has been added!"
	else
		echo "autolanip add failed; continuing!"
	fi
fi

#删除ddnsto菜单栏一级菜单DDNSTO（Dev）
DDNSTO_DIR="$(find "$PACKAGE_PATH" -maxdepth 1 -type d -name '*luci-app-ddnsto*' -print -quit)"
if [ -n "$DDNSTO_DIR" ]; then
	echo " "
	DDNSTO_LUA="$(find "$DDNSTO_DIR" -type f -name 'ddnsto.lua' -print -quit)"
	if [ -n "$DDNSTO_LUA" ]; then
		if sed -i '/entry({"admin", "ddnsto_dev"},/d; /^function action_ddnsto_dev()/,/^end$/d' "$DDNSTO_LUA"; then
			echo "ddnsto(Dev) has been removed!"
		else
			echo "ddnsto(Dev) remove failed; continuing!"
		fi
	else
		echo "ddnsto lua not found; continuing!"
	fi
fi

#修改argon主题字体和颜色
if [ -d "$PACKAGE_PATH/luci-theme-argon" ]; then
	echo " "
	if sed -i "s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
		"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"; then
		echo "theme-argon has been fixed!"
	else
		echo "theme-argon fix failed; continuing!"
	fi
fi

#修改aurora菜单式样
if [ -d "$PACKAGE_PATH/luci-app-aurora-config" ]; then
	echo " "
	if find "$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec \
		sed -i "s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +; then
		echo "theme-aurora has been fixed!"
	else
		echo "theme-aurora fix failed; continuing!"
	fi
fi

#修改mini-diskmanager菜单位置
if [ -d "$PACKAGE_PATH/luci-app-mini-diskmanager" ]; then
	echo " "
	if sed -i "s/services/system/g" \
		"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"; then
		echo "mini-diskmanager has been fixed!"
	else
		echo "mini-diskmanager fix failed; continuing!"
	fi
fi

#修改natmapt菜单位置
if [ -d "$PACKAGE_PATH/luci-app-natmapt" ]; then
	echo " "
	if sed -i "s/network/services/g" \
		"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"; then
		echo "natmapt has been fixed!"
	else
		echo "natmapt fix failed; continuing!"
	fi
fi

#修复QModem依赖循环
if [ -d "$PACKAGE_PATH/QModem" ]; then
	echo " "
	if sed -i 's/@!PACKAGE_luci-app-qmodem //g; s/+luci-app-qmodem-next/luci-app-qmodem-next/g' \
		"$PACKAGE_PATH/QModem/luci/luci-app-qmodem-next/Makefile"; then
		echo "QModem has been fixed!"
	else
		echo "QModem fix failed; continuing!"
	fi
fi

#修复Rust编译失败
if [ -d "$FEEDS_PATH/packages/lang/rust" ]; then
	echo " "
	if sed -i 's/ci-llvm=true/ci-llvm=false/g' \
		"$FEEDS_PATH/packages/lang/rust/Makefile"; then
		echo "rust has been fixed!"
	else
		echo "rust fix failed; continuing!"
	fi
fi
