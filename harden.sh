#!/usr/bin/env bash
# This script incorporates code from:
#   Ubuntu-Hardening (https://github.com/AndyHS-506/Ubuntu-Hardening)
#   Copyright (c) AndyHS-506
#
# Original code is licensed under the GNU Affero General Public License v3.0
# https://www.gnu.org/licenses/agpl-3.0.html
#
# Modifications copyright (c) [tomkabel] [2025]
# 
# This file and all modifications are distributed under the GNU AGPLv3.

# Global Variables
LOG_DIR="/home/$SUDO_USER/setup_logs/hardening.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CURRENT_SECTION=""

# Setup directories
mkdir -p "$(dirname "$LOG_DIR")"
mkdir -p "$LOG_DIR/section_logs"

# Logging functions
start_section() {
    CURRENT_SECTION="$1"
    echo "[$(date '+%H:%M:%S')] Starting SECTION $CURRENT_SECTION" | tee -a "$LOG_DIR/main.log"
    mkdir -p "$LOG_DIR/section_logs/$CURRENT_SECTION"
}

log_success() {
    echo "  [✓] $1" | tee -a "$LOG_DIR/section_logs/$CURRENT_SECTION/success.log"
}

log_error() {
    echo "  [✗] $1" | tee -a "$LOG_DIR/section_logs/$CURRENT_SECTION/error.log"
}

run_command() {
    local cmd="$1"
    local desc="$2"
    echo "  EXEC: $desc" >> "$LOG_DIR/section_logs/$CURRENT_SECTION/details.log"
    if eval "$cmd" >> "$LOG_DIR/section_logs/$CURRENT_SECTION/details.log" 2>&1; then
        log_success "$desc"
    else
        log_error "$desc"
    fi
}

# ===============[ SECTION 1: Initial Setup ]===============
start_section "1.1"
run_command "apt purge -y cramfs freevxfs hfs hfsplus overlayfs squashfs udf jffs2 usb-storage" "1.1.1 Remove unnecessary filesystems"
run_command "systemctl mask autofs" "1.1.2 Disable autofs service"

start_section "1.2"
run_command "apt update && apt upgrade -y" "1.2.1 Update system packages"
run_command "chown root:root /boot/grub/grub.cfg" "1.2.2 Set grub.cfg ownership"
run_command "chmod og-rwx /boot/grub/grub.cfg" "1.2.3 Set grub.cfg permissions"

start_section "1.3"
run_command "apt install -y apparmor-utils apparmor-profiles apparmor-profiles-extra" "1.3.1 Install AppArmor"
for profile in /etc/apparmor.d/*; do
  if grep -q '^profile ' "$profile"; then
    aa-complain "$profile"
  fi
done
run_command 'echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/60-aslr.conf' "1.3.3 Enable ASLR"
run_command 'echo "kernel.yama.ptrace_scope = 1" > /etc/sysctl.d/60-yama.conf' "1.3.4 Restrict ptrace"
run_command "sysctl --system" "1.3.5 Apply kernel settings"

start_section "1.4"
run_command 'echo "* hard core 0" >> /etc/security/limits.conf' "1.4.1 Disable core dumps"
run_command 'echo "fs.suid_dumpable = 0" > /etc/sysctl.d/60-coredump.conf' "1.4.2 Disable suid dumping"
run_command "sysctl -p /etc/sysctl.d/60-coredump.conf" "1.4.3 Apply coredump settings"

start_section "1.5"
run_command "apt purge -y prelink" "1.5.1 Remove prelink"
run_command "apt purge -y apport" "1.5.2 Remove apport"
run_command "apt install -y unattended-upgrades" "1.5.3 Install unattended-upgrades"

start_section "1.6"
BANNER=$(cat << 'EOF'
******************************************************
*                                                    *
*          Authorized Access Only                   *
*                                                    *
******************************************************

This system is for authorized use only. Unauthorized access or use is prohibited and may result in disciplinary action and/or civil and criminal penalties.

All activities on this system are subject to monitoring and recording. By using this system, you expressly consent to such monitoring and recording.

Legal Notice:
-------------
Use of this system constitutes consent to security monitoring and testing. All activities are logged and monitored.
Unauthorized access, use, or modification of this system or its data may result in disciplinary action, civil, and/or criminal penalties.

**Important Security Measures:**
1. **Do not share your login credentials.**
2. **Report any suspicious activity to IT security immediately.**
3. **Adhere to the security policies and guidelines.**
EOF
)
run_command "echo \"$BANNER\" > /etc/issue.net" "1.6.1 Set login banner"
run_command "echo \"$BANNER\" > /etc/issue"     "1.6.1 Set login banner"
run_command "echo \"$BANNER\" > /etc/motd"      "1.6.1 Set login banner"
run_command "chmod -x /etc/update-motd.d/*"     "1.6.2 Disable standard motd scripts"
run_command "chmod 644 /etc/issue.net /etc/issue /etc/motd" "1.6.3 Set banner permissions"
run_command "chown root:root /etc/issue.net /etc/issue /etc/motd" "1.6.4 Set banner ownership"

start_section "1.7"
run_command "dpkg -l gdm3 >/dev/null 2>&1 && apt purge -y gdm3 || true" "1.7.1 Remove GDM3 if installed"

start_section "1.8"
MOUNT_POINTS=(/home /tmp /var /var/log /var/log/audit /var/tmp /dev/shm)
for mp in "${MOUNT_POINTS[@]}"; do
  if mount | grep -q "on $mp "; then
    log_success "$mp is on a dedicated partition"
  else
    log_error "$mp is NOT on a dedicated partition"
  fi
done

# ===============[ SECTION 2: Services ]===============
start_section "2.1"
services=(
    avahi-daemon autofs isc-dhcp-server bind9 dnsmasq vsftpd slapd
    nfs-kernel-server ypserv cups rpcbind rsync samba snmpd tftpd-hpa
    squid apache2 nginx xinetd xserver-common telnetd postfix
    nis rsh-client talk talkd telnet inetutils-telnet ldap-utils ftp tnftp lp
)
for service in "${services[@]}"; do
    run_command "dpkg -l $service >/dev/null 2>&1 && apt purge -y $service || true" "2.1.1 Remove $service"
done

start_section "2.4"
run_command "apt purge -y chrony" "2.4.1 Remove Chrony"
run_command "grep -q '^\[Time\]' /etc/systemd/timesyncd.conf || echo '[Time]' >> /etc/systemd/timesyncd.conf" "2.4.2 Configure timesyncd"
run_command "sed -i '/^\[Time\]/a NTP=time-a-wwv.nist.gov time-d-wwv.nist.gov' /etc/systemd/timesyncd.conf" "2.4.3 Set NTP servers"
run_command "sed -i '/^\[Time\]/a FallbackNTP=time-b-wwv.nist.gov time-c-wwv.nist.gov' /etc/systemd/timesyncd.conf" "2.4.4 Set fallback NTP"
run_command "systemctl restart systemd-timesyncd" "2.4.5 Restart timesync"
run_command "systemctl enable systemd-timesyncd"  "2.4.6 Enable timesync"

start_section "2.5"
run_command "chown root:root /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d" "2.5.1 Set cron ownership"
run_command "chmod og-rwx /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d" "2.5.2 Set cron permissions"

# ===============[ SECTION 3: Network Configuration ]===============
start_section "3.1"
run_command 'echo "net.ipv6.conf.all.disable_ipv6 = 1"     > /etc/sysctl.d/60-ipv6.conf' "3.1.1 Disable IPv6"
run_command 'echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/60-ipv6.conf' "3.1.2 Disable IPv6 default"
run_command 'echo "net.ipv6.conf.lo.disable_ipv6 = 1"      >> /etc/sysctl.d/60-ipv6.conf' "3.1.3 Disable IPv6 loopback"
run_command "sysctl -p /etc/sysctl.d/60-ipv6.conf"         "3.1.4 Apply IPv6 settings"
run_command "apt purge -y bluez bluetooth"                "3.1.5 Remove Bluetooth"

start_section "3.2"
modules=(dccp tipc rds sctp)
for mod in "${modules[@]}"; do
    run_command "echo 'install $mod /bin/false' >> /etc/modprobe.d/disable.conf" "3.2.1 Disable $mod"
    run_command "modprobe -r $mod 2>/dev/null || true"    "3.2.2 Unload $mod"
done

start_section "3.3"
run_command 'echo "net.ipv4.ip_forward = 0"                 > /etc/sysctl.d/60-net.conf' "3.3.1 Disable IP forwarding"
run_command 'echo "net.ipv4.conf.all.send_redirects = 0"    >> /etc/sysctl.d/60-net.conf' "3.3.2 Disable redirects"
run_command 'echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> /etc/sysctl.d/60-net.conf' "3.3.3 Ignore bogus errors"
run_command 'echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.d/60-net.conf' "3.3.4 Ignore ICMP broadcasts"
run_command 'echo "net.ipv4.conf.all.accept_redirects = 0"   >> /etc/sysctl.d/60-net.conf' "3.3.5 Disable ICMP redirects"
run_command 'echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.d/60-net.conf' "3.3.6 Disable default redirects"
run_command 'echo "net.ipv4.tcp_syncookies = 1"             >> /etc/sysctl.d/60-net.conf' "3.3.7 Enable SYN cookies"
run_command "sysctl -p /etc/sysctl.d/60-net.conf"         "3.3.8 Apply network settings"

# =======[ SECTION 4: Host Based Firewall – REMOVED ]=======

# ===============[ SECTION 5: Configure SSH Server ]===============
start_section "5.1"
SSH_CONF=$(cat << 'EOF'
Include /etc/ssh/sshd_config.d/*.conf
LogLevel VERBOSE
PermitRootLogin no
MaxAuthTries 3
MaxSessions 2
IgnoreRhosts yes
PermitEmptyPasswords no
KbdInteractiveAuthentication no
UsePAM yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
TCPKeepAlive no
PermitUserEnvironment no
ClientAliveCountMax 2
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server
LoginGraceTime 60
MaxStartups 10:30:60
ClientAliveInterval 15
Banner /etc/issue.net
Ciphers -3des-cbc,aes128-cbc,aes192-cbc,aes256-cbc,chacha20-poly1305@openssh.com
DisableForwarding yes
GSSAPIAuthentication no
HostbasedAuthentication no
KexAlgorithms -diffie-hellman-group1-sha1,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1
MACs -hmac-md5,hmac-md5-96,hmac-ripemd160,hmac-sha1-96,umac-64@openssh.com,hmac-md5-etm@openssh.com,hmac-md5-96-etm@openssh.com,hmac-ripemd160-etm@openssh.com,hmac-sha1-96-etm@openssl.com,umac-64-etm@openssl.com,umac-128-etm@openssl.com
PermitUserEnvironment no
EOF
)
run_command "echo \"$SSH_CONF\" > /etc/ssh/sshd_config" "5.1.* Configuration of SSH server"
run_command "systemctl enable ssh" "5.1.1 Enable SSH service"
run_command "systemctl restart ssh" "5.1.2 Restart SSH service"

start_section "5.2"
run_command 'echo "Defaults logfile=/var/log/sudo.log" > /etc/sudoers.d/01_base'      "5.2.1 Configure sudo logging"
run_command 'echo "Defaults log_input,log_output"          >> /etc/sudoers.d/01_base'      "5.2.2 Configure sudo I/O logging"
run_command 'echo "Defaults use_pty"                       >> /etc/sudoers.d/01_base'      "5.2.3 Enable sudo PTY constraint"
run_command 'echo "Defaults env_reset, timestamp_timeout=15" >> /etc/sudoers.d/01_base'  "5.2.6 Reset in 15 minutes"
run_command "chmod 440 /etc/sudoers.d/01_base"                                               "5.2.4 Set sudoers file permissions"
run_command "visudo -c -f /etc/sudoers.d/01_base"                                            "5.2.5 Validate sudoers syntax"

start_section "5.4"
run_command 'sed -i "/^PASS_MAX_DAYS/c\PASS_MAX_DAYS 180" /etc/login.defs'    "5.4.1.1 Set password max days to 180"
run_command 'sed -i "/^PASS_MIN_DAYS/c\PASS_MIN_DAYS 7"   /etc/login.defs'    "5.4.1.1 Set password min days to 7"
run_command 'sed -i "/^PASS_WARN_AGE/c\PASS_WARN_AGE 14"  /etc/login.defs'    "5.4.1.1 Set password warning age to 14"
run_command "useradd -D -f 30"                                                "5.4.1.2 Set inactive account lock to 30 days"
#run_command "apt install -y libpam-pwquality"                                 "5.4.1.3 Install pwquality"
#run_command 'sed -i "/pam_pwquality.so/c\password requisite pam_pwquality.so retry=3 minlen=14 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" /etc/pam.d/common-password' "5.4.1.3 Configure password complexity"
#run_command 'echo "password required pam_pwhistory.so remember=5 use_authtok" >> /etc/pam.d/common-password' "5.4.1.4 Limit password reuse"
run_command 'sed -i "/^ENCRYPT_METHOD/c\ENCRYPT_METHOD SHA512" /etc/login.defs'  "5.4.1.5 Set password hashing to SHA512"
run_command 'sed -i "/^UMASK/c\UMASK 077"           /etc/login.defs'            "5.4.2 Set default umask to 077"
run_command 'echo "TMOUT=1800" > /etc/profile.d/timeout.sh'                    "5.4.2 Set shell timeout (30 min)"
run_command 'chmod +x /etc/profile.d/timeout.sh'                               "5.4.2 Make timeout script executable"
run_command 'passwd -l root'                                                   "5.4.3 Lock root account"
run_command 'echo "umask 027" >> /etc/bash.bashrc'                             "5.4.4 Set bash default umask"
run_command 'echo "umask 027" >> /root/.bash_profile'                          "5.4.4 Set bash default root umask"
run_command 'echo "umask 027" >> /root/.bashrc'                                 "5.4.4 Set bash default root umask"

start_section "5.5"
run_command 'awk -F: '\''($2 == "" ) { print $1 " does not have a password" }'\'' /etc/shadow | tee /var/log/empty_passwords.log'               "5.5.1 Audit empty passwords"
run_command 'grep "^+:" /etc/passwd | tee /var/log/legacy_passwd_entries.log'                                                      "5.5.2 Audit legacy NIS entries"
run_command 'awk -F: '\''($3 == 0) { print $1 }'\'' /etc/passwd | grep -v "^root$" | tee /var/log/uid0_accounts.log'                   "5.5.3 Audit duplicate UID 0 accounts"
run_command 'awk -F: '\''($3 == 0) { print $1 }'\'' /etc/passwd | grep -v "^root$" | xargs -r -n1 passwd -l'                              "5.5.6 Lock empty password accounts"

# ===============[ SECTION 6: Logging and Auditing ]===============
start_section "6.1"
run_command "apt install -y auditd audispd-plugins"      "6.1.1 Install auditd"
run_command "systemctl --now enable auditd"             "6.1.1 Enable auditd service"

RULES=$(cat << 'EOF'
-D
-b 8192
-f 1
# (… your full list of audit rules goes here …)
EOF
)
run_command "echo \"$RULES\" > /etc/audit/rules.d/50-scope.rules" "6.1.2 Configure audit rules"
run_command 'echo "max_log_file = 50"      >> /etc/audit/auditd.conf' "6.1.3 Set max audit log size (50MB)"
run_command 'echo "max_log_file_action = rotate" >> /etc/audit/auditd.conf' "6.1.3 Configure log rotation"
run_command 'echo "num_logs = 10"         >> /etc/audit/auditd.conf' "6.1.3 Configure log rotation"
run_command 'echo "disk_full_action = rotate" >> /etc/audit/auditd.conf' "6.1.3 Configure disk alerts"
run_command 'echo "space_left_action = email" >> /etc/audit/auditd.conf'  "6.1.3 Configure disk alerts"

start_section "6.2"
run_command "apt install -y rsyslog"           "6.2.1 Install rsyslog"
run_command "systemctl --now enable rsyslog"  "6.2.1 Enable rsyslog"
run_command 'echo "*.emerg :omusrmsg:*"           >> /etc/rsyslog.d/50-default.conf' "6.2.2 Emergency alerts"
run_command 'echo "mail.* -/var/log/mail.log"       >> /etc/rsyslog.d/50-default.conf' "6.2.2 Mail logging"
run_command 'echo "auth,authpriv.* /var/log/auth.log" >> /etc/rsyslog.d/50-default.conf' "6.2.2 Auth logging"
run_command 'find /var/log -type f -exec chmod 640 {} \;' "6.2.3 Secure log file permissions"
run_command 'find /var/log -type d -exec chmod 750 {} \;' "6.2.3 Secure log dir permissions"
run_command 'chmod 640 /var/log/sudo.log'           "6.2.3 Secure sudo log"

start_section "6.3"
run_command 'cat > /etc/logrotate.d/sudo << "EOF"
/var/log/sudo.log {
    rotate 12
    monthly
    compress
    missingok
}
EOF
' "6.3.1 Configure sudo log rotation"
run_command 'echo "Storage=persistent" >> /etc/systemd/journald.conf' "6.3.2 Enable persistent journal"
run_command 'echo "SystemMaxUse=250M" >> /etc/systemd/journald.conf' "6.3.2 Limit journal size"
run_command 'systemctl restart systemd-journald'     "6.3.2 Restart journald"

start_section "6.4"
run_command "apt install -y acct"                 "6.4.1 Install process accounting"
run_command "systemctl --now enable psacct"       "6.4.1 Enable process accounting"
run_command 'echo "-w /usr/bin/ -p x -k processes" >> /etc/audit/rules.d/50-processes.rules' "6.4.2 Monitor binary execution"
run_command 'echo "-a always,exit -F arch=b64 -S execve -k processes" >> /etc/audit/rules.d/50-processes.rules' "6.4.2 Audit execve"
run_command "service auditd restart"              "6.4.2 Reload audit rules"

# ===============[ SECTION 7: File Permissions ]===============
start_section "7.1"
run_command "chmod 644 /etc/passwd"           "7.1.1 /etc/passwd perms"
run_command "chown root:root /etc/passwd"     "7.1.2 /etc/passwd owner"
run_command "chmod 000 /etc/shadow"           "7.1.3 /etc/shadow perms"
run_command "chown root:shadow /etc/shadow"   "7.1.4 /etc/shadow owner"
run_command "chmod 644 /etc/group"            "7.1.5 /etc/group perms"
run_command "chown root:root /etc/group"      "7.1.6 /etc/group owner"
run_command "chmod 000 /etc/gshadow"          "7.1.7 /etc/gshadow perms"
run_command "chown root:shadow /etc/gshadow"  "7.1.8 /etc/gshadow owner"
run_command "chmod 600 /etc/passwd-"          "7.1.9 /etc/passwd- backup perms"
run_command "chown root:root /etc/passwd-"    "7.1.10 /etc/passwd- backup owner"
run_command "chmod 600 /etc/shadow-"          "7.1.11 /etc/shadow- backup perms"
run_command "chown root:shadow /etc/shadow-"  "7.1.12 /etc/shadow- backup owner"
run_command "chmod 600 /etc/group-"           "7.1.13 /etc/group- backup perms"
run_command "chown root:root /etc/group-"     "7.1.14 /etc/group- backup owner"
run_command "chmod 600 /etc/gshadow-"         "7.1.15 /etc/gshadow- backup perms"
run_command "chown root:shadow /etc/gshadow-" "7.1.16 /etc/gshadow- backup owner"

# Final report
echo -e "\nHardening complete. Summary of errors:"
grep -r "\[✗\]" "$LOG_DIR/section_logs/" | tee "$LOG_DIR/error_summary.log"
echo -e "\nFull logs available in: $LOG_DIR"
