# FIRA Simulation ROS 2 Bridge

[English](README.EN.md) | Bahasa Indonesia

Menjalankan [FIRA Autonomous Cars Simulator](src/FIRA-Autonomous-Cars-Simulator)
(Gazebo + ROS 1 Noetic) bersama `ros1_bridge` (ROS 2 Jazzy) dalam satu
container podman. Topik yang tercantum di `bridge_config.yaml` di-bridge
sehingga simulasi dapat dikendalikan dan diamati dari ROS 2.

## Kebutuhan

- [podman](https://podman.io/)
- Sesi X11 (GUI Gazebo ditampilkan di display host)
- `/dev/dri` untuk rendering GPU
- `xhost` (opsional, digunakan agar container dapat membuka jendela)

## Mulai cepat

```bash
./run_container.sh
```

Perintah ini menjalankan simulasi dan bridge sekaligus. Jika tidak ada image
lokal, image siap pakai akan diunduh dari
`ghcr.io/internship-iris-its/fira_simulation_ros2_docker`.

Lalu, dari shell ROS 2 Jazzy di mesin yang sama (dengan `ROS_DOMAIN_ID` yang
sama):

```bash
source /opt/ros/jazzy/setup.bash
ros2 topic list
```

## Skrip

Setiap skrip menerima `-h`/`--help`.

| Skrip              | Fungsi                                                         |
| ------------------ | -------------------------------------------------------------- |
| `run_container.sh` | Menjalankan simulasi dan bridge dalam container                |
| `build.sh`         | Membangun image secara lokal sebagai `fira_simulation_ros2_docker` |
| `pull.sh`          | Mengunduh image siap pakai terbaru dari GHCR                   |
| `entrypoint.sh`    | Entrypoint container (tidak dijalankan langsung di host)       |

### `run_container.sh`

```
./run_container.sh [opsi] [perintah...]
```

| Opsi                     | Deskripsi                                                  |
| ------------------------ | ---------------------------------------------------------- |
| `-b`, `--build`          | Bangun image secara lokal terlebih dahulu (menjalankan `build.sh`) |
| `-r`, `--remote`         | Paksa memakai image GHCR, walaupun image lokal ada         |
| `-d`, `--domain-id N`    | Atur `ROS_DOMAIN_ID` (bawaan `0`)                          |
| `--localhost-only`       | Atur `ROS_LOCALHOST_ONLY=1` (bawaan `0`)                   |
| `-h`, `--help`           | Tampilkan bantuan                                          |

`perintah` opsional diteruskan ke entrypoint container:

| Perintah  | Efek                                               |
| --------- | -------------------------------------------------- |
| `all`     | Simulasi dan bridge (bawaan)                       |
| `sim`     | Hanya simulasi Gazebo                              |
| `bridge`  | Hanya `ros1_bridge` parameter bridge               |
| lainnya   | Dijalankan apa adanya, mis. `bash` untuk shell     |

Contoh:

```bash
./run_container.sh -d 42            # pakai ROS_DOMAIN_ID=42
./run_container.sh sim              # hanya simulasi
./run_container.sh bash             # shell di dalam container
```

### Image yang dipakai

Aturan pertama yang cocok akan dipakai:

1. Variabel lingkungan `IMAGE`
2. `--remote`: image GHCR
3. `--build`: image lokal, dibangun ulang terlebih dahulu
4. Image lokal `fira_simulation_ros2_docker`, jika ada
5. Image GHCR

## Memakai image siap pakai

Podman hanya mengunduh image remote saat pertama kali. Untuk memperbaruinya:

```bash
./pull.sh
```

Jika Anda punya image lokal `fira_simulation_ros2_docker`, image tersebut
diprioritaskan. Jalankan dengan `--remote`, atau hapus image lokalnya:

```bash
./run_container.sh --remote
# atau
podman rmi fira_simulation_ros2_docker
```

Jika paket GHCR bersifat privat, login terlebih dahulu dengan
`podman login ghcr.io`.

## Membangun secara lokal

```bash
./build.sh                # membangun fira_simulation_ros2_docker
./run_container.sh        # sekarang memakai image lokal
```

Atau bangun dan jalankan sekaligus dengan `./run_container.sh --build`.

## Variabel lingkungan

| Variabel         | Dipakai oleh                              | Deskripsi                                         |
| ---------------- | ----------------------------------------- | ------------------------------------------------- |
| `IMAGE`          | `run_container.sh`, `build.sh`, `pull.sh` | Menimpa nama/tag image                            |
| `CONTAINER_NAME` | `run_container.sh`                        | Nama container (bawaan `fira_simulation_ros2_docker`) |

## Topik yang di-bridge

Ubah `bridge_config.yaml` untuk mengatur topik yang di-bridge, lalu bangun
ulang image (`./build.sh`).
