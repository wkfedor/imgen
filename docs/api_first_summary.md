# API-first summary для imgen

## Проблема

В проекте есть веб-интерфейс для человека, но агенту нужен такой же полноценный структурированный интерфейс. Если поведение существует только в HTML-контроллерах, views или browser-only JavaScript, агенту приходится парсить HTML или автоматизировать браузер. Это хрупко и делает автоматизацию сложнее, чем обычное использование сервиса.

Целевое состояние — паритет: все, что человек может сделать в веб-интерфейсе, должно быть доступно через JSON API со стабильными ID, статусами, ошибками, URL картинок и документированными форматами request/response.

## Выбранное решение

Использовать обычные Rails versioned API controllers под `/api/v1`, общие service objects для бизнес-логики и OpenAPI/Swagger-документацию, генерируемую из request specs через `rswag`.

Это лучше всего подходит текущему проекту, потому что это уже компактное Rails MVC-приложение. Существующие контроллеры уже содержат бизнес-действия для `ImageRequest`, `ImageResult`, `PromptProject` и `PromptRun`; добавление Grape привнесет второй API-framework и отдельный DSL без достаточной пользы.

## Почему этот вариант

Rails namespaced controllers — распространенный Rails-подход для versioned APIs: routes живут под `/api/v1`, controllers живут под `Api::V1`. Это держит реализацию ближе к Rails-конвенциям и не добавляет второй framework.

OpenAPI/Swagger здесь полезен, потому что агенту нужен machine-readable contract, а не только документация для человека. `rswag` — практичный Rails-вариант, потому что request specs могут одновременно описывать и проверять endpoints, а также генерировать OpenAPI output.

Самое важное архитектурное правило — не дублировать бизнес-логику между HTML и API controllers. UI и API должны вызывать одни и те же operation/service classes, чтобы поведение не расходилось.

## Целевая архитектура

1. Добавить `Api::V1::BaseController` для общих JSON helpers и error envelopes.
2. Добавить `Api::V1::ImageRequestsController` для list, create, show, retry и destroy.
3. Добавить `Api::V1::ImageResultsController` для regenerate и delete image.
4. Добавить `Api::V1::PromptProjectsController` для list, create, show и run.
5. Добавить `Api::V1::PromptRunsController` и `Api::V1::PromptFeedbacksController` для просмотра run и feedback.
6. Вынести shared operations из существующих controllers в service objects: например create image request, retry image request, regenerate image result, delete image result, create prompt project и run prompt revision.
7. HTML controllers оставить с текущими redirect/render, но state-changing работу делегировать тем же service objects, что и API.
8. Добавить request specs для API endpoints.
9. Добавить `rswag` и генерировать OpenAPI docs из request specs.

## Форма routes

```ruby
namespace :api do
  namespace :v1 do
    resources :image_requests, only: %i[index create show destroy] do
      post :retry, on: :member
    end

    resources :image_results, only: [] do
      post :regenerate, on: :member
      delete :destroy_image, on: :member
    end

    resources :prompt_projects, only: %i[index create show] do
      post :run, on: :member
    end

    resources :prompt_runs, only: %i[show] do
      resources :prompt_feedbacks, only: %i[create]
    end

    get :models, to: "image_requests#models"
  end
end
```

## Контракт ответа

Успешный ответ:

```json
{
  "ok": true,
  "data": {},
  "error": null
}
```

Ответ с ошибкой:

```json
{
  "ok": false,
  "data": null,
  "error": {"message": "human-readable error"}
}
```

## Правило UI/API parity

Любое будущее изменение UI должно включать проверку API parity. Если в интерфейс добавляется или меняется user-facing action, такое же поведение должно быть доступно через API или явно добавлено в план реализации.

Предпочтительный путь реализации:

1. вынести бизнес-логику в shared service object;
2. вызвать его из HTML controller;
3. вызвать его из API controller;
4. покрыть API behavior request specs;
5. держать OpenAPI/Swagger documentation сгенерированной из specs или синхронизированной с ними.

## Решение

Использовать Rails `/api/v1` controllers, shared service objects и `rswag` OpenAPI documentation. Не использовать Grape для текущего объема проекта.
