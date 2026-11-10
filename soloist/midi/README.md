# Soloist на Станции Миди

Проверено на Яндекс Станции Миди (`yandexmidi`, системная glibc 2.36, ALSA `default` → dmix 96 кГц)
со Spotiya 0.10.1 и Soloist 1.3.10.51.

## Что не работает из коробки

Пакет совместимости Soloist из релиза 0.10.1 ставится и логинится, но звука нет:
в приложении Spotify трек сразу встаёт на паузу, затем станция пропадает из списка устройств.

| Симптом | Причина |
|---|---|
| `playing` → через ~150 мс `paused`, в verbose-логе `Unable to initialize AudioDriver, using dummy` и `playback_error_audio_driver` | `libpulse.so.0` (apulse) из пакета не загружается: `undefined symbol: __ldexp`, затем `__frexp` — этих символов нет в glibc 2.38 из того же пакета |
| После подмены символов: `snd1_pcm_hw_param_get_min: Assertion '!snd_interval_empty(i)' failed`, либо `Segmentation fault` (код 139) | та же сборка apulse падает в ALSA при открытии потока FLOAT32LE 44,1 кГц |
| В статусе Spotiya `Soloist: WebSocket protocol error: Connection reset without closing handshake` | следствие: Soloist аварийно завершился |

Посмотреть самому:

```sh
LD_BIND_NOW=1 LD_PRELOAD=/data/opt/solo/lib/libpulse.so.0 \
  /data/opt/solo/ld.so --library-path /data/opt/solo/lib:/usr/lib:/lib /bin/true; echo rc=$?
```

`rc=0` без сообщений — библиотека загружается; иначе будет назван недостающий символ.

## Исправление

Штатный apulse 0.1.13 из Ubuntu 24.04 (armhf) работает с glibc 2.38 из пакета и системной
`/usr/lib/libasound.so.2`. В нём меняется одна инструкция: `pa_context_set_sink_input_volume`
только подтверждает запрос и не меняет уровень потока. Громкостью уже управляет Spotiya через
ALSA `Master`; без этого изменения громкость применяется дважды (50% в приложении ≈ 25% на выходе).

Спектр на дисплее при этом недоступен: он есть только в apulse из Spotiya.

Установка с компьютера (нужны `curl`, `tar` с поддержкой zstd, `ssh`; SSH на станции — dropbear, порт 2222):

```sh
sh soloist/midi/install.sh 192.168.1.50
```

Скрипт:

1. `make-libpulse.sh` скачивает `apulse_0.1.13-2build2_armhf.deb` с ports.ubuntu.com, сверяет SHA-256
   пакета, извлечённой библиотеки и результата после правки двух байт;
2. кладёт результат в `/data/opt/libpulse.so.0.novol`, а `spotiya-fix.sh` — в `/data/opt/`;
3. добавляет вызов `spotiya-fix.sh` в `start` у `/etc/init.d/S99spotify-connect`;
4. перезапускает Spotify Connect.

`spotiya-fix.sh` при каждом запуске сравнивает `/data/opt/solo/lib/libpulse.so.0` с сохранённой копией
и возвращает её, если файл изменился. Поэтому после `spotiya addon install soloist`
(сборки Soloist живут 90 дней, потом процесс выходит с кодом 10) достаточно `spotiya restart`.

Откат: удалить строку со `spotiya-fix.sh` из `/etc/init.d/S99spotify-connect` и вернуть
`/data/opt/solo/lib/libpulse.so.0.orig`.

## Сборка Spotiya под Миди

Системная glibc Миди — 2.36, поэтому бинарник можно собрать против Debian bookworm без тулчейна Linaro:

```sh
docker run --rm -v "$PWD":/src -v spotiya-target:/target \
  -v spotiya-cargo:/usr/local/cargo/registry rust:1-bookworm sh /src/scripts/build-docker-bookworm.sh
```

Результат — `spotiya.armv7` в корне репозитория (требует glibc ≥ 2.34, на Мини 1/2 не запустится).
Установка на станцию:

```sh
ssh -p 2222 root@STATION 'spotiya stop; cp /data/opt/spotify-connect/spotiya /data/opt/spotify-connect/spotiya.orig'
ssh -p 2222 root@STATION 'cat > /data/opt/spotify-connect/spotiya && chmod 755 /data/opt/spotify-connect/spotiya' < spotiya.armv7
ssh -p 2222 root@STATION 'spotiya start'
```

`spotiya update` заменит бинарник на официальный — после обновления установку нужно повторить.

## Громкость

Spotiya отображает `Master` линейно: 50% в Spotify = 128/255. Алиса использует свою шкалу поверх того же
регулятора (её значения не совпадают с процентами `Master`), поэтому числа в Spotify и у Алисы расходятся,
а фактическая громкость одна и та же.
