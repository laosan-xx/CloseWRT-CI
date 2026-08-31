#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认密码 password
sed -i "s/root:.*/root:\$5\$MZloauSqpcvpjtZb\$NuVJ6qEGPkanc7\/986bDfZnF22V43GXfxl00hhremR4:20440:0:99999:7:::/g" $(find ./package/base-files/files/etc/ -type f -name "shadow")

# TTYD 免登录
#sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

WIFI_FILE="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
#修改WIFI名称（双频统一为WRT_SSID）
sed -i "s/ImmortalWrt-\(2\.4G\|5G\)/$WRT_SSID/g" $WIFI_FILE
#修改无线信道（源码为channel=auto，无引号；按频段分别固定，5G用149避开DFS）
sed -i 's|set wireless\.\${dev}\.channel=auto|set wireless.${dev}.channel=${chan}|g' $WIFI_FILE
sed -i 's|ssid="ImmortalWrt-2.4G"|ssid="ImmortalWrt-2.4G"\n\t\t\tchan="11"|g' $WIFI_FILE
sed -i 's|ssid="ImmortalWrt-5G"|ssid="ImmortalWrt-5G"\n\t\t\tchan="149"|g' $WIFI_FILE
sed -i 's|ssid="ImmortalWrt-6G"|ssid="ImmortalWrt-6G"\n\t\t\tchan="37"|g' $WIFI_FILE
#5G降为80MHz（160MHz在5G必然横跨DFS信道，且部分客户端无法关联）
sed -i 's|htmode="HE160"|htmode="HE80"|g' $WIFI_FILE
#修改WIFI加密
sed -i "s/encryption=.*/encryption='psk2+ccmp'/g" $WIFI_FILE
#修改WIFI密码
sed -i "/set wireless.default_\${dev}.encryption='psk2+ccmp'/a \\\t\t\t\t\t\set wireless.default_\${dev}.key='$WRT_WORD'" $WIFI_FILE

#修复cudy TR3000(ubootmod)被写入非法BSSID
#09-fix-mtwifi-mac从bdinfo 0xde00取MAC，该机型该偏移是组播地址(d1:fd:...)，客户端会拒绝关联
#（表现为搜得到SSID但连不上/提示密码错误）。只摘除该机型，不影响其他cudy机型
MTWIFI_MAC_FILE="./target/linux/mediatek/filogic/base-files/etc/hotplug.d/net/09-fix-mtwifi-mac"
if [ -f "$MTWIFI_MAC_FILE" ] && grep -q 'cudy,tr3000-v1-ubootmod' "$MTWIFI_MAC_FILE"; then
	echo " "
	if sed -i '/cudy,tr3000-v1-ubootmod|\\/d' "$MTWIFI_MAC_FILE" && sh -n "$MTWIFI_MAC_FILE"; then
		echo "cudy tr3000-ubootmod has been removed from 09-fix-mtwifi-mac!"
	else
		echo "09-fix-mtwifi-mac fix failed; continuing!"
	fi
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# 自定义脚本同步（Others/uci-defaults → package/base-files/files/etc/uci-defaults）
UCI_DEFAULTS_DIR="./package/base-files/files/etc/uci-defaults"
CUSTOM_UCI_DEFAULTS="${GITHUB_WORKSPACE:+$GITHUB_WORKSPACE/Others/uci-defaults}"
CUSTOM_UCI_DEFAULTS="${CUSTOM_UCI_DEFAULTS:-../Others/uci-defaults}"

mkdir -p "$UCI_DEFAULTS_DIR"

if [ -d "$CUSTOM_UCI_DEFAULTS" ] && find "$CUSTOM_UCI_DEFAULTS" -maxdepth 1 -type f | grep -q .; then
	while IFS= read -r FILE; do
		BASENAME=$(basename "$FILE")
		cp -f "$FILE" "$UCI_DEFAULTS_DIR/$BASENAME"
		chmod +x "$UCI_DEFAULTS_DIR/$BASENAME"
	done < <(find "$CUSTOM_UCI_DEFAULTS" -maxdepth 1 -type f)

	echo "已同步自定义 uci-defaults 脚本到: $UCI_DEFAULTS_DIR"
else
	echo "未找到自定义 uci-defaults 脚本，跳过同步"
fi

#固定无线BSSID（2.4G写死，5G由驱动按"第4字节+0x10"自动推导）
#注意：同一份固件的所有设备BSSID相同，多机同网会冲突；需要区分请改这里，或用WRT_WIFI_MAC覆盖
WIFI_MAC_24="${WRT_WIFI_MAC:-86:b0:a5:8b:70:3b}"
#dat模板由wifi-dats包提供，最终安装到固件的/etc/wireless/mediatek/
WIFI_DAT_DIR="./package/mtk/drivers/wifi-profile/files"
echo " "

#校验：aa:bb:cc:dd:ee:ff 且首字节为偶数（奇数=组播地址，客户端会拒绝关联，表现为密码错误/卡验证）
WIFI_MAC_VALID=0
case "$WIFI_MAC_24" in
	[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F]:[0-9a-fA-F][0-9a-fA-F])
		[ $(( 0x${WIFI_MAC_24%%:*} & 0x01 )) -eq 0 ] && WIFI_MAC_VALID=1
		;;
esac

if [ "$WIFI_MAC_VALID" -ne 1 ]; then
	echo "invalid WIFI_MAC_24: $WIFI_MAC_24 (need aa:bb:cc:dd:ee:ff, first octet even); using the default bssid!"
else
	IFS=: read -r m1 m2 m3 m4 m5 m6 <<< "$WIFI_MAC_24"
	WIFI_MAC_5G="$m1:$m2:$m3:$(printf '%02x' $(( (0x$m4 + 0x10) % 0x100 ))):$m5:$m6"

	#直接改dat模板（b0=第一频段即2.4G，b1的MacAddress无效不改）
	WIFI_DAT_FILES="$(find "$WIFI_DAT_DIR" -type f -name '*.dbdc.b0.dat' 2>/dev/null)"
	if [ -n "$WIFI_DAT_FILES" ]; then
		WIFI_DAT_OK=1
		while IFS= read -r WIFI_DAT; do
			if grep -q '^MacAddress=' "$WIFI_DAT"; then
				sed -i "s/^MacAddress=.*/MacAddress=$WIFI_MAC_24/" "$WIFI_DAT" || WIFI_DAT_OK=0
			else
				echo "MacAddress=$WIFI_MAC_24" >> "$WIFI_DAT" || WIFI_DAT_OK=0
			fi
		done <<< "$WIFI_DAT_FILES"

		if [ "$WIFI_DAT_OK" -eq 1 ]; then
			echo "wifi bssid has been set: 2.4G=$WIFI_MAC_24 5G=$WIFI_MAC_5G"
		else
			echo "wifi bssid set failed; continuing!"
		fi
	else
		echo "WARNING: no *.dbdc.b0.dat under $WIFI_DAT_DIR, wifi bssid NOT set!"
	fi
fi

# 安装 tmd 到 /usr/bin/tmd（编译期从目标仓库在线下载）
USR_BIN_DIR="./package/base-files/files/usr/bin"
mkdir -p "$USR_BIN_DIR"
curl -fsSL "https://raw.githubusercontent.com/laosan-xx/diy-shell/main/wrt/tmd.sh" -o "$USR_BIN_DIR/tmd" \
	&& chmod +x "$USR_BIN_DIR/tmd" \
	&& echo "已安装 tmd 到系统: $USR_BIN_DIR/tmd" \
	|| echo "错误：下载 tmd 失败，跳过安装。" >&2

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
# echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi
