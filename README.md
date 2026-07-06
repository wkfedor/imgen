# Imgen Comparator

Rails-приложение для сравнения checkpoint-моделей ComfyUI. Пользователь вводит один промпт, выбирает модели чекбоксами, запрос уходит в Sidekiq-очередь, а результаты появляются как набор превью по каждой модели.

## Запуск

Приложение запускается через Foreman и `Procfile`: одним процессом поднимается Rails web-сервер, вторым — Sidekiq worker для очереди `imgen`.

```bash
cd /home/feda/imgen
ruby -S bundle _2.4.22_ exec rails db:migrate
redis-server --daemonize yes # если Redis ещё не запущен
bin/dev
```

Открыть: `http://127.0.0.1:4567`.

`bin/dev` использует `Procfile`:

```Procfile
web: ruby -S bundle _2.4.22_ exec rails server -b 127.0.0.1 -p ${PORT:-4567}
worker: ruby -S bundle _2.4.22_ exec sidekiq -q imgen
```

Важно: Rails server только ставит задания в очередь. Генерацию выполняет Sidekiq worker из `Procfile`, поэтому запускать приложение нужно через `bin/dev`, а не только через `rails server`.

Если нужно запустить процессы вручную, команды такие:

```bash
ruby -S bundle _2.4.22_ exec sidekiq -q imgen
ruby -S bundle _2.4.22_ exec rails server -b 127.0.0.1 -p 4567
```

## ComfyUI

Приложение при загрузке страницы получает список моделей с сервера автоматически:

- прямой URL: `COMFYUI_URL`, по умолчанию `http://192.168.0.106:8188`;
- fallback через SSH: `IMGEN_SSH_HOST=feda@192.168.0.106`, ключ `IMGEN_SSH_KEY=/home/feda/.ssh/cursor_remote_key`, удалённый URL `COMFYUI_REMOTE_URL=http://127.0.0.1:8188`.

Сгенерированные изображения сохраняются локально в `/home/feda/imgen/storage/generated` и показываются через `/generated_images/:id`.

## Заливка в GitHub

В интерфейсе есть кнопка **Залить в Git**. Она работает внутри этого Rails-приложения и не зависит от Yandex checker или других скриптов.

Кнопка вызывает `POST /git_push`, а backend выполняет в корне `/home/feda/imgen`:

```bash
git add -A
git commit -m "Imgen: update YYYY-MM-DD HH:MM:SS"
git push -u origin <текущая-ветка>
```

Remote по умолчанию: `https://github.com/wkfedor/imgen.git`. Его можно переопределить переменной `IMGEN_GIT_REMOTE`.

## Проверка

```bash
cd /home/feda/imgen
ruby -S bundle _2.4.22_ exec rails test
```

* ...
