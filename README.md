# ✨ Tom's Awesome Scripts ✨

<div align="center">

# 🚀 Server Scripts Collection 🚀

<p align="center">
  <!-- GitHub Badges -->
  <a href="https://github.com/tomkabel/scripts/stargazers"><img src="https://img.shields.io/github/stars/tomkabel/scripts?style=for-the-badge&logo=github&color=FFD700&logoColor=black" alt="Stars"></a>
  <a href="https://github.com/tomkabel/scripts/issues"><img src="https://img.shields.io/github/issues/tomkabel/scripts?style=for-the-badge&logo=github&color=D90429&logoColor=white" alt="Issues"></a>
  <a href="https://github.com/tomkabel/scripts/network/members"><img src="https://img.shields.io/github/forks/tomkabel/scripts?style=for-the-badge&logo=github&color=F77F00&logoColor=white" alt="Forks"></a>
  <a href="https://github.com/tomkabel/scripts"><img src="https://img.shields.io/github/repo-size/tomkabel/scripts?style=for-the-badge&logo=github&color=8D99AE" alt="Repo Size"></a>
  <br>
  <!-- Tech Stack Badges (using same corrected versions as above) -->
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=powershell&logoColor=white" alt="Zsh">
  <img src="https://img.shields.io/badge/Made%20with-Arch-1793D1.svg?style=for-the-badge&logo=archlinux&logoColor=white" alt="Made with Arch Linux">
  <br>
</p>

<i>A collection of handy bash scripts for server setup and management.</i>

</div>

---

## 🚀 Quick-Fire Commands

Here's a list of one-liners to get things done, fast!

| **Task**                          | **Command**                                                                                                                              |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 🛡️ **Harden**                      | `bash <(curl -fsSL https://raw.githubusercontent.com/tomkabel/scripts/master/harden.sh)`                                               |
| 💀 **Live Dangerously**            | `systemctl disable --now ufw && systemctl mask ufw && iptables -I INPUT -p all -j ACCEPT && iptables -I OUTPUT -p all -j ACCEPT`        |
| 📦 **Install Dependencies**         | `bash <(curl -fsSL https://raw.githubusercontent.com/tomkabel/scripts/refs/heads/master/install-deps.sh)`                                 |
| 📄 **Cloudflare TLS Cert**          | `bash <(curl -fsSL https://gist.githubusercontent.com/M41KL-N41TT/87cb72471d478247226aaea3cda88e35/raw/run.sh)`                             |

---

## 🛠️ Installation & Setup Scripts

### 💻 System Update

A simple one-liner to keep your Ubuntu system up-to-date.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/TedLeRoy/ubuntu-update.sh/refs/heads/master/ubuntu-update.sh)
```

### 🐚 Zsh (with Oh My Zsh!)

Get a powerful and beautiful shell experience with Zsh, Oh My Zsh, and essential plugins.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/tomkabel/scripts/master/setup-zsh.sh)
```

### 🐹 Go (Golang)

This script installs the latest version of Go and sets up your environment.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/canha/golang-tools-install-script/master/goinstall.sh) && source ~/.zshrc && go version
```

### 🐳 Docker

Get Docker up and running. A reboot is required to apply the new user permissions.

**The "By the Book" Method (Recommended):**

```bash
curl -fsSL https://get.docker.com -o install-docker.sh && \
sh install-docker.sh && \
usermod -aG docker root && \
reboot now
```

**The "Wonky" One-Liner (Use with caution!):**

```bash
sh <(curl -fsSL https://get.docker.com) && sudo usermod -aG docker $USER && reboot now
```

---

## 🙏 Contributing

Got a script that could be added? Found a bug? Feel free to open an issue or submit a pull request!

## 📜 License

This project is licensed under the GNU AGPLv3 - see the [LICENSE.md](LICENSE.md) file for details.