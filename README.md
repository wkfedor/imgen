# Imgen Comparator

Rails-приложение для сравнения checkpoint-моделей ComfyUI. Пользователь вводит один промпт, выбирает модели чекбоксами, запрос уходит в Sidekiq-очередь, а результаты появляются как набор превью по каждой модели.

## Запуск

Приложение для разработки запускается через Foreman и `Procfile.dev`: одним процессом поднимается отдельный dev-Redis на порту `6380`, вторым — Rails web-сервер, третьим — Sidekiq worker для очереди `imgen`.

```bash
cd /home/feda/imgen
ruby -S bundle _2.4.22_ exec rails db:migrate
ruby -S bundle _2.4.22_ exec foreman start -f Procfile.dev
```

Открыть: `http://127.0.0.1:4567`.

`bin/dev` запускает ту же команду Foreman:

```bash
bin/dev
```

`Procfile.dev` содержит все локальные сервисы:

```Procfile
redis: redis-server --port 6380 --save "" --appendonly no
web: REDIS_URL=redis://127.0.0.1:6380/0 ruby -S bundle _2.4.22_ exec rails server -b 127.0.0.1 -p ${PORT:-4567}
worker: REDIS_URL=redis://127.0.0.1:6380/0 ruby -S bundle _2.4.22_ exec sidekiq -q imgen
```

Dev-Redis использует порт `6380`, чтобы не конфликтовать с уже запущенным системным Redis на `6379`.

Важно: Rails server только ставит задания в очередь. Генерацию выполняет Sidekiq worker из `Procfile.dev`, поэтому запускать приложение нужно через Foreman или `bin/dev`, а не только через `rails server`.

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

У каждой готовой картинки есть кнопка **Удалить картинку**. Она удаляет локальную копию из `storage/generated` и файл на ComfyUI-сервере `http://192.168.0.106` через SSH-доступ `IMGEN_SSH_HOST`.

У каждого prompt-запроса есть кнопка **Удалить промпт**. Она удаляет сам prompt из базы и предварительно удаляет все связанные картинки локально и на ComfyUI-сервере.

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
