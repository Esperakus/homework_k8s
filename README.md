# Домашняя работа "Настройка конфигурации веб приложения под высокую нагрузку"

Цель работы - создать стенд веб приложения с балансировкой и отказоусточивостью как nginx так и бэкенда, распределённой GFS2 на бэкендах выданных по iSCSI с отдельного хранилища. На балансировщиках nginx необходимо провести тюнинг операционной системы и самого nginx.

Данный репозиторий содержит:

- Манифесты terraform для создания инфраструктуры проекта:
  - штатный балансировщик yandex.cloud, который будет проводить периодически health-check воркеров nginx и балансировать входящий трафик между ними
  - 2 воркера nginx, которые в свою очередь настроены на простейшую балансировку трафика на бэкенды веб приложения
  - 2 воркера бэкенда, на которых в systemd запущено простейшее приложение на go, слушающее порт 8090. При запросе отдаёт имя бэкенда (чтобы понять, на какой бэкенд прилетел запрос из Nginx) и версию БД
  - 1 iscsi target, раздающий диск в бэкенды
  - 1 экземпляр БД Postgresql 13 c базой test и пользователем БД test, чтоб принимать запросы от бэкенда
  - и, наконец, виртуалка с установленным ансиблем, чтоб развернуть вышеупомянутые роли. Выступает так же в роли Jump host проекта, поскольку единственная имеет внешний ip (не считая балансировщика yandex.cloud, он тоже имеет внешний ip)

- Роли ansible для приведения виртуальных машин в проекте в требуемое состояние.

При разворачивании стенда создаются ВМ с параметрами:
- 2 CPU;
- 2 GB RAM;
- 10 GB диск;
- операционная система Almalinux 8;

Для разворачивания стенда необходимо:

1. Заполнить значение переменных cloud_id, folder_id и iam-token в файле **variables.tf**.

2. Инициализировать рабочую среду Terraform:

```
$ terraform init
```
В результате будет установлен провайдер для подключения к облаку Яндекс.

3. Запустить разворачивание стенда:
```
$ terraform apply
```
В выходных данных будут показаны все внешние и внутренни ip адреса. Для проверки работы стенда необходимо в браузере или с помощью curl зайти на ip адрес балансировщика yandex.cloud, который можно посмотреть в выходных данных, например:

```
Пример вывода terraform apply:

...
external_ip_address_lb = tolist([
  {
    "external_address_spec" = toset([
      {
        "address" = "51.250.84.78"
        "ip_version" = "ipv4"
...
```
заходим на ip балансировщика из браузера или с помощью curl (можно в сочетании с watch, чтоб наглядно видеть смену бэкендов):
```
curl http://{external_ip_address_lb}
```
в выводе увидим:
```
backend0.ru-central1.internal
```
или
```
backend1.ru-central1.internal
```
что говорит о том, что запрос может перенаправляться Nginx на разные бэкенды.

Ответ от БД можно посмотреть по url http://{external_ip_address_lb}/db
```
PostgreSQL 13.9 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 8.5.0 20210514 (Red Hat 8.5.0-15), 64-bit
```

Вывод картинки с подключенной по iSCSI GFS2 можно увидеть по url http://{external_ip_address_lb}/image

Можно зайти по ssh на джамп-хост, с которого можно попасть на любую ВМ внутри стенда. Для этого из рабочей папки проекта надо выполнить:

```
$ ssh almalinux@{external_ip_address_ansible} -i id_rsa
```
**external_ip_address_ansible** посмотреть в выводе terraform или консоли yandex.cloud.

С джамп-хоста можно ходить по ssh по всем машинам внутри проекта по их внутренним ip адресам или hostname (nginx0, nginx1, backend0, backend1, db, iscsi).

Если останавливать по одной службы nginx на балансировщиках nginx0, nginx1, можно увидеть, что запросы всё равно идут к бэкендам благодаря работе балансировщика yandex.cloud.

Если останавливать по одному backend0, backend1, можно увидеть, что запросы будут идти только на работающий бэкенд благодаря работе балансировки в nginx. Обработка статики (вывод картинки) также продолжит работать. Если запустить выключенный бэкенд снова - оба бэкенда будут в работе спустя некоторое время. 

"Тюнинг" Nginx.
На серверах nginx выполнены следующие настройки для улучшения производительности:
1. Настройки операционной системы:
   - увеличение ulimits hard и soft для nginx до 65536
   - увеличение sysctl fs.file-max до 324567
2. Настройки nginx:
   - sendfile on;
   - tcp_nopush on;
   - types_hash_max_size 2048;
   - gzip on;
   - gzip_disable "msie6";
   - gzip_proxied any;
   - gzip_comp_level 3;
   - gzip_buffers 16 8k;
   - gzip_http_version 1.1;
   - gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;
