Containers for ezdev
====================
docker compose build --progress plain base

# base builds 
# docker buildx bake --push --set *.platform=linux/amd64,linux/arm64 base-alpine-dev base-alpine-prod base-debian-dev base-ubuntu-dev
# docker compose build --progress plain node-alpine-dev
Build and Test:
```bash
ARCH="amd64"
ARCH="arm64"
docker buildx bake --load --set *.platform=linux/$ARCH $IMAGE;
docker compose -f docker-compose-dev.yml run --rm $IMAGE-$ARCH
```

IMAGES:
```bash
IMAGE="base-alpine-dev"
IMAGE="base-alpine-prod" 
IMAGE="base-debian-dev" 
IMAGE="base-ubuntu-dev"
IMAGE="nginx-alpine-prod"
IMAGE="certbot-alpine-prod"
IMAGE="php-alpine-dev" 
IMAGE="php-alpine-prod"
IMAGE="node-alpine-dev"
IMAGE="node-alpine-prod"
IMAGE="node-debian-dev"
IMAGE="node-debian-qa"
```
Final build:
```bash
docker buildx bake --push --set *.platform=linux/amd64,linux/arm64 $IMAGE;
```
Final test:
```bash
ARCHS=("arm64" "amd64")

for ARCH in "${ARCHS[@]}"; do \
    docker compose -f docker-compose-dev.yml run --rm $IMAGE-$ARCH; \
done
```

IMAGES=("php-alpine-dev" "php-alpine-prod")
IMAGES=("node-alpine-dev" "node-alpine-prod")
IMAGES=("node-debian-dev" "node-debian-qa")

For windows:

- go to wsl:
  - edit /etc/passwd to add /mnt/c/users/<username> as home directory
  - edit /etc/wsl.conf to add
    ```
    [automount]
    enabled = true
    options = "metadata"
    ```
- Connect VSCode to wsl, and then open the project folder, and then open in container

# docker compose --progress plain -f docker-compose-build.yml build base
# docker compose -f docker-compose-build.yml push ai-pytorch ai-tflm ai-tflm-with-jupyter-service conda conda-with-jupyter conda-with-jupyter-service base node iot

# export DUID="$(id -u)"; export DGID="$(id -g)"


