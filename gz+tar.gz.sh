#!/bin/sh
# ========== 自定义目录名 留空默认=m 可改为m1/m2随便改 ==========
CUSTOM_DIR=""
# ==========================================================

# 为空默认 m
[ -z "$CUSTOM_DIR" ] && CUSTOM_DIR="m"
BASE_DIR="/etc/${CUSTOM_DIR}"

# 1. 创建自定义目录
mkdir -p "${BASE_DIR}"

# 2. 优先匹配 tar.gz 内核，没有再匹配 gz 内核
TAR_GZ=$(ls /tmp/*.tar.gz 2>/dev/null | head -n1)
GZ_FILE=$(ls /tmp/*.gz 2>/dev/null | grep -v zip | grep -v tar.gz 2>/dev/null | head -n1)

# 处理 tar.gz
if [ -n "$TAR_GZ" ]; then
    tar -zxf "$TAR_GZ" -C "${BASE_DIR}/"
    TMP_BIN=$(find "${BASE_DIR}" -maxdepth 1 ! -path "${BASE_DIR}" | head -n1)
    if [ -n "$TMP_BIN" ]; then
        rm -rf "${BASE_DIR}/mihomo"
        mv -f "$TMP_BIN" "${BASE_DIR}/mihomo"
        chmod +x "${BASE_DIR}/mihomo"
    fi
    echo "✅ ${TAR_GZ} 解压并重命名 → ${BASE_DIR}/mihomo"
# 处理普通 .gz
elif [ -n "$GZ_FILE" ]; then
    gunzip -q "$GZ_FILE" -c > "${BASE_DIR}/mihomo"
    chmod +x "${BASE_DIR}/mihomo"
    echo "✅ ${GZ_FILE} 解压生成 → ${BASE_DIR}/mihomo"
fi

# 3. 自动匹配任意 .zip 解压后重命名为 ui
UI_ZIP=$(ls /tmp/*.zip 2>/dev/null | head -n1)
if [ -n "$UI_ZIP" ]; then
    unzip -o -q "$UI_ZIP" -d "${BASE_DIR}/"
    TMP_UI_DIR=$(find "${BASE_DIR}" -maxdepth 1 -type d ! -path "${BASE_DIR}" | head -n1)
    if [ -n "$TMP_UI_DIR" ]; then
        rm -rf "${BASE_DIR}/ui"
        mv -f "$TMP_UI_DIR" "${BASE_DIR}/ui"
    fi
    echo "✅ ${UI_ZIP} 解压并重命名 → ${BASE_DIR}/ui"
fi

# 4. 匹配 /tmp 任意 yaml 覆盖为 config.yaml
TMP_YAML=$(ls /tmp/*.yaml 2>/dev/null | head -n1)
if [ -n "$TMP_YAML" ]; then
    cp -f "$TMP_YAML" "${BASE_DIR}/config.yaml"
    echo "✅ 已覆盖 ${BASE_DIR}/config.yaml"
else
    echo "ℹ️ /tmp 无 yaml 文件，跳过覆盖"
fi

# 5. 写入开机服务 自动适配自定义目录
cat > /etc/init.d/mihomo << EOF
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

MIHOMO_BIN="${BASE_DIR}/mihomo"
MIHOMO_CONFIG_DIR="${BASE_DIR}"
PID_FILE="/var/run/mihomo.pid"

start_service() {
    if [ -z "\${MIHOMO_CONFIG_DIR}" ]; then
        echo "错误：请先填写配置文件夹路径"
        exit 1
    fi
    mkdir -p "\${MIHOMO_CONFIG_DIR}"
    procd_open_instance mihomo
    procd_set_param command "\${MIHOMO_BIN}"
    procd_append_param command -d "\${MIHOMO_CONFIG_DIR}"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall -q mihomo 2>/dev/null || true
    rm -f "\${PID_FILE}"
}
EOF
chmod +x /etc/init.d/mihomo

# 6. 管理面板
cat > /etc/mihomo_panel.sh << 'EOF'
#!/bin/sh
while true; do
    clear
    echo "=================================="
    echo "      Mihomo 管理面板"
    echo "=================================="
    echo "1. 启动 Mihomo"
    echo "2. 停止 Mihomo"
    echo "3. 重启 Mihomo"
    echo "4. 查看进程状态"
    echo "5. 查看运行日志"
    echo "6. 启用开机自启"
    echo "7. 关闭开机自启"
    echo "0. 退出面板"
    echo "=================================="
    read -p "请输入数字选择: " CHOICE

    case $CHOICE in
        1)
            echo "正在启动 Mihomo..."
            /etc/init.d/mihomo start
            read -p "按回车继续..."
            ;;
        2)
            echo "正在停止 Mihomo..."
            /etc/init.d/mihomo stop
            read -p "按回车继续..."
            ;;
        3)
            echo "正在重启 Mihomo..."
            /etc/init.d/mihomo restart
            read -p "按回车继续..."
            ;;
        4)
            echo "进程状态:"
            ps | grep mihomo | grep -v grep
            read -p "按回车继续..."
            ;;
        5)
            echo "运行日志（按 Ctrl+C 退出）:"
            logread -f | grep mihomo
            read -p "按回车继续..."
            ;;
        6)
            echo "正在启用开机自启..."
            /etc/init.d/mihomo enable
            echo "已启用开机自启"
            read -p "按回车继续..."
            ;;
        7)
            echo "正在关闭开机自启..."
            /etc/init.d/mihomo disable
            echo "已关闭开机自启"
            read -p "按回车继续..."
            ;;
        0)
            echo "退出面板"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入"
            read -p "按回车继续..."
            ;;
    esac
done
EOF
chmod +x /etc/mihomo_panel.sh

# 7. 别名 m
grep -q 'alias m=' /etc/profile || echo "alias m='/etc/mihomo_panel.sh'" >> /etc/profile
source /etc/profile

echo -e "\n🎉 部署完成，工作目录：${BASE_DIR}"
echo "👉 输入 m 进入管理面板"
