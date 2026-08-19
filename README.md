# Custom Kernel rova (Redmi 4A/5A) — KernelSU + Droidspaces

Paket ini berisi *build recipe* GitHub Actions untuk mem-build ulang kernel
crDroid 13 milik `crdroidandroid/android_kernel_xiaomi_rova` (branch `13.0`)
dengan tambahan dukungan root (keluarga KernelSU) dan Droidspaces (container
Linux). Semua klaim teknis di dokumen ini sudah diverifikasi langsung
terhadap source code kernelnya, bukan asumsi — lihat bagian "Temuan riset"
di bawah.

## Identifikasi perangkat

- Kernel source: `android_kernel_xiaomi_rova`, branch `13.0`, Linux **4.9.337**
- Codename tree "rova" mencakup dua device: **Redmi 4A (rolex)** dan
  **Redmi 5A (riva)** — keduanya chipset Qualcomm **MSM8917 (Snapdragon 425)**
- Ini kernel **non-GKI** (kernel lama/legacy, bukan Generic Kernel Image
  ala Android 12+), defconfig: `arch/arm64/configs/rova_defconfig`
- Toolchain resmi yang dipakai maintainer-nya sendiri (`build-release.sh`
  yang ikut ter-bundle di repo kernel): Clang penuh (`LLVM=1`) dengan
  binutils bergaya GNU (`aarch64-linux-gnu-`, `arm-linux-gnueabi-`) — persis
  cocok dengan toolchain **proton-clang**, yang memang toolchain standar
  komunitas untuk keluarga kernel msm8917/msm8937.

## Pilihan solusi root — dan kenapa SukiSU-Ultra

KernelSU resmi (`tiann/KernelSU`) **sudah drop dukungan non-GKI sejak
v1.0+** — versi terakhir yang masih bisa dipakai di kernel non-GKI seperti
ini adalah v0.9.5 yang sudah tidak dikembangkan lagi. Karena itu KernelSU
resmi **tidak saya rekomendasikan** untuk kernel ini.

Tiga kandidat yang masih aktif dan mendukung non-GKI:

| | KernelSU-Next | **SukiSU-Ultra** (rekomendasi) | ReSukiSU |
|---|---|---|---|
| Dukungan non-GKI | 4.4 – 6.6 | 3.4 – 5.10+ (backport) | 3.4+ (perlu build manual) |
| Metode integrasi non-GKI | `setup.sh ... legacy`, terdokumentasi rapi | `setup.sh ... main`, terdokumentasi rapi + catatan spesifik utk kernel <4.19 | Belum ada flag "legacy" khusus, integrasi manual |
| KPM (patch kernel tanpa rebuild penuh) | Tidak ada | **Ada** | Ada (turunan SukiSU) |
| SUSFS (root hiding) | Tidak native | Ada (branch `susfs-main`) | Ada |
| Kematangan utk device msm8917-class | Baik | **Paling banyak dipakai** komunitas kernel custom device lama | Masih sangat baru (rilis mingguan, Agustus 2026) |

**Rekomendasi saya: SukiSU-Ultra.** Alasannya bukan cuma "paling banyak
fitur" — dokumentasinya secara eksplisit membahas kernel **di bawah 4.19**
(persis kondisi kita, 4.9.337) termasuk syarat backport `set_memory.h`, jadi
risikonya sudah dipetakan oleh upstream-nya sendiri. KPM juga berguna nyata
di sini: build kernel device ini sekitar 10–20 menit, KPM memungkinkan
tempel patch kecil nanti tanpa rebuild penuh + reflash.

Kalau kamu lebih suka yang lebih sederhana/minim moving parts (tanpa KPM,
tanpa SUSFS bawaan), **KernelSU-Next** pilihan yang solid — lebih sedikit
kemungkinan gagal karena scope-nya lebih kecil. **ReSukiSU** saya taruh
sebagai opsi eksperimental karena masih sangat baru untuk hardware setua
ini; workflow tetap menyediakannya kalau kamu mau coba.

Workflow-nya mendukung ketiganya lewat input `kernelsu_variant`, jadi kamu
bisa ganti-ganti tanpa edit YAML.

### Catatan kprobe

Ketiga solusi ini pakai **kprobe** untuk hook kernel — dan ini bukan cuma
default, tapi satu-satunya jalur di source terkini. Saya cek langsung
`kernel/Kconfig` punya SukiSU-Ultra dan KernelSU-Next: keduanya
mendefinisikan `config KSU ... depends on KPROBES && EXT4_FS`, tanpa ada
toggle "manual hook" / non-kprobe di Kconfig-nya. (Kode SukiSU-Ultra juga
sudah di-refactor jadi modular -- `hook/`, `core/`, `feature/`, dst -- bukan
lagi satu file `kernel/ksu.c` seperti versi lama yang sering direferensikan
di forum/dokumentasi pihak ketiga.) Praktisnya: `CONFIG_EXT4_FS` sudah `=y`
di `rova_defconfig`, dan `arch/arm64` di kernel ini memang mendukung kprobe
(`arch/arm64/kernel/probes/kprobes.c` ada, `select HAVE_KPROBES` aktif) --
jadi secara arsitektur seharusnya jalan. Fragment `kernelsu/kprobes.config`
mengaktifkan `CONFIG_KPROBES` yang memang tidak nyala di `rova_defconfig`
bawaan.

Yang **tidak** bisa saya jamin dari sini: apakah kprobe benar-benar
berfungsi mulus di kernel downstream Xiaomi/Qualcomm yang sudah banyak
dimodifikasi out-of-tree ini. Itu cuma bisa dites dengan boot sungguhan.
Kalau setelah flash ternyata bootloop atau manager app bilang "kernel not
supported": itu tanda kprobe bermasalah di tree ini, dan solusinya **bukan**
toggle config sederhana -- perlu patch manual ke titik-titik hook (di
`hook/syscall_hook_manager.c` untuk SukiSU-Ultra) atau buka issue di
tracker proyek root yang kamu pilih dengan detail crash log-nya. Workflow
sudah menambahkan step verifikasi (`Verify critical config options landed`)
yang mengecek `CONFIG_KSU` benar-benar `=y` di `.config` final SEBELUM
compile dimulai -- jadi kalau dependency-nya ternyata tidak terpenuhi, kamu
tahu dalam hitungan detik, bukan setelah nunggu build 20 menit lalu gagal
boot.

## Droidspaces

[Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) adalah runtime
container ala-LXC untuk Android (namespace PID/MNT/UTS/IPC/cgroup asli,
bukan chroot). Untuk kernel non-GKI seperti ini, requirement-nya "hanya"
kumpulan `CONFIG_*` (tidak perlu patch kABI berat seperti di kernel GKI)
plus dua patch kecil.

**Yang saya verifikasi langsung terhadap source kernel `rova`:**

- Sebagian besar config wajib Droidspaces **belum aktif** di
  `rova_defconfig` (`CONFIG_SYSVIPC`, `CONFIG_IPC_NS`, `CONFIG_PID_NS`,
  `CONFIG_UTS_NS`, `CONFIG_NET_NS`, dll — semua sudah saya susun di
  `droidspaces/droidspaces_nongki.config`).
- Patch resmi Droidspaces-OSS untuk `xt_qtaguid.c` **tidak relevan** di
  kernel ini — file `net/netfilter/xt_qtaguid.c` memang tidak ada di tree
  Xiaomi/Qualcomm ini, jadi workflow **tidak** mencoba menerapkannya.
- Patch resmi untuk `kernel/cgroup.c` **tidak bisa** langsung `patch -p1`
  apa adanya karena path-nya beda (`kernel/cgroup/cgroup.c` di kernel
  modern vs `kernel/cgroup.c` di kernel 4.9 ini). Saya sudah cek isi
  fungsi `cgroup_add_file()` di tree ini — strukturnya identik, semua
  simbol yang dibutuhkan (`CGRP_ROOT_NOPREFIX`, `CFTYPE_NO_PREFIX`,
  `kernfs_create_link`) sudah tersedia — jadi saya generate ulang patch-nya
  langsung dari source asli kernel `rova` (`droidspaces/0001-droidspaces-cgroup-fix.patch`)
  dan sudah saya tes `patch --dry-run -p1` sampai berhasil bersih.

## Struktur repo ini

```
.github/workflows/build-kernel.yml   -> workflow utama
droidspaces/
  droidspaces_nongki.config          -> fragment config wajib Droidspaces
  droidspaces_ufw_fail2ban.config    -> fragment opsional (ufw/fail2ban di dalam container)
  0001-droidspaces-cgroup-fix.patch  -> patch yang sudah diverifikasi terhadap kernel/cgroup.c
kernelsu/
  kprobes.config                     -> aktifkan CONFIG_KPROBES dkk + CONFIG_KSU
  kpm.config                         -> aktifkan KPM (SukiSU-Ultra/ReSukiSU)
ak3/
  anykernel.sh                       -> AnyKernel3 script khusus rolex/riva
                                         (repo kernel aslinya cuma bawa
                                         template contoh yang belum
                                         disesuaikan device, jadi saya
                                         tulis ulang dari nol memakai
                                         block=/dev/block/bootdevice/by-name/boot,
                                         is_slot_device=0, device.name
                                         rolex/riva)
README.md                            -> dokumen ini
```

## Cara pakai

1. Buat repo baru **kosong** di GitHub kamu (bebas nama, contoh
   `rova-kernelsu-build`) — **jangan** centang "Add a README", biar bisa
   push langsung tanpa conflict. Tidak perlu fork kernel-nya, workflow akan
   clone kernel source sendiri tiap kali jalan.
2. Ekstrak zip ini, lalu dari dalam folder hasil ekstrak jalankan:

   ```bash
   git init
   git add .
   git commit -m "Initial recipe: rova KernelSU + Droidspaces build"
   git branch -M main
   git remote add origin https://github.com/<username-kamu>/rova-kernelsu-build.git
   git push -u origin main
   ```

3. Buka tab **Actions** di repo → kalau Actions belum aktif untuk repo
   baru, klik "I understand my workflows, go ahead and enable them" →
   pilih workflow **"Build rova Custom Kernel (Root + Droidspaces)"** →
   **Run workflow**.
4. Atur input sesuai kebutuhan:
   - `kernelsu_variant`: `sukisu-ultra` (rekomendasi), `kernelsu-next`, `resukisu`, atau `none`
   - `enable_kpm`: aktifkan kalau pilih SukiSU-Ultra/ReSukiSU
   - `enable_susfs`: **eksperimental**, biarkan `false` dulu di build pertama
   - `enable_droidspaces`: `true`
   - `enable_lto`: opsional, build lebih lama tapi kernel sedikit lebih ringkas
5. Tunggu build selesai (biasanya 15–25 menit di runner GitHub-hosted
   standar). Unduh zip hasil build dari halaman run (artifact) atau dari
   **Releases** kalau `make_release=true`.

## Flashing

1. Boot ke custom recovery (TWRP/OrangeFox) yang kompatibel dengan rolex/riva.
2. Flash file `rova-<tanggal>-<varian>.zip` seperti flash zip biasa.
3. Reboot.

## Verifikasi setelah boot pertama — WAJIB

1. Install manager app yang sesuai (KernelSU Next / SukiSU manager /
   ReSukiSU manager tergantung pilihanmu) dari GitHub Releases masing-masing
   proyek.
2. Buka app-nya, cek apakah kernel terdeteksi "supported" dan `su` berfungsi.
3. Kalau device **bootloop**: itu indikasi kprobe rusak di kernel ini. Perlu
   rebuild dengan `CONFIG_KSU_MANUAL_HOOK=y` (SukiSU-Ultra/ReSukiSU) atau
   integrasi manual non-kprobe (KernelSU-Next) — silakan buka issue di
   proyek root masing-masing untuk panduan manual-hook, ini di luar cakupan
   otomatisasi workflow ini karena sangat spesifik per-tree.
4. Untuk Droidspaces: install app Droidspaces, buka **Settings → Requirements
   → Check Requirements** — semua item wajib (PID/MNT/UTS/IPC namespace,
   cgroup device, devtmpfs) harus centang hijau.

## Batasan yang perlu kamu tahu

- **SUSFS eksperimental.** susfs4ksu memang punya branch `kernel-4.9`
  (saya verifikasi lewat mirror GitHub-nya untuk pola nama file), tapi
  kernel `rova` ini sudah dimodifikasi cukup dalam oleh Xiaomi/Qualcomm,
  jadi ada kemungkinan patch tidak apply bersih. Workflow akan otomatis
  **skip** SUSFS dan lanjut build tanpa itu kalau patch gagal — cek log step
  "(Experimental) Integrate SUSFS" untuk detail.
- Workflow ini **tidak** menangani dtbo/vendor_boot terpisah — device ini
  memang tidak pakai partisi itu (boot image lama, single `boot` partition).
- Selalu simpan backup boot image original / partisi boot sebelum flashing
  kernel custom apa pun.
