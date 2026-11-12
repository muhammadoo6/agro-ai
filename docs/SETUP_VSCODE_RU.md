# Agro AI — что установить и как запускать в VS Code

Проект состоит из двух частей:

| Часть | Язык | Где лежит | Чем запускается |
|---|---|---|---|
| Мобильное приложение | Dart (Flutter) | `lib/`, `test/`, `integration_test/` | Flutter SDK + телефон или эмулятор Android |
| Обучение нейросети | Python | `tools/train/` | Python 3.11 + TensorFlow |

## 1. Программы (ставятся один раз)

| № | Программа | Зачем | Где взять |
|---|---|---|---|
| 1 | **Git** | история кода, GitHub | git-scm.com |
| 2 | **VS Code** | редактор | code.visualstudio.com |
| 3 | **Flutter SDK 3.47** (в нём уже есть Dart) | собирать и запускать приложение | docs.flutter.dev → Get started → Windows → Android |
| 4 | **Android Studio** | Android SDK, эмулятор телефона, JDK 17 (встроенный) | developer.android.com/studio |
| 5 | **Python 3.11** (именно 3.11) | обучение и проверка модели | python.org → Downloads → 3.11.x; при установке поставить галочку «Add python.exe to PATH» |

> Для iPhone нужен Mac с Xcode. Без Mac сборка для iPhone идёт в облаке GitHub Actions (`.github/workflows/ios.yml`).

### Проверка после установки (в терминале VS Code)

```bash
git --version
flutter --version
flutter doctor
python --version
```

`flutter doctor` должен показать зелёные галочки у **Flutter** и **Android toolchain**.
Если ругается на лицензии Android, выполните:

```bash
flutter doctor --android-licenses
```

## 2. Расширения VS Code

Откройте папку проекта (**File → Open Folder → `D:\Agro AI`**). VS Code сам предложит
«Install recommended extensions» — нажмите **Install All**. Список лежит в `.vscode/extensions.json`:

| Расширение | Для чего |
|---|---|
| Flutter, Dart | подсветка, подсказки, запуск и отладка приложения |
| Python, Pylance | запуск скриптов обучения |
| Jupyter | (по желанию) пробовать код по кусочкам |
| SQLite | открыть файл базы данных `agro_ai.db` и посмотреть таблицы |
| YAML, GitHub Actions | файлы облачной сборки в `.github/workflows/` |
| GitLens | история каждой строки кода |
| Error Lens | ошибки прямо в строке |

## 3. Первый запуск приложения

```bash
flutter pub get
```

1. Подключите Android-телефон по USB (в телефоне: **Настройки → О телефоне → 7 раз нажать «Номер сборки»**,
   потом **Для разработчиков → Отладка по USB**) или запустите эмулятор из Android Studio.
2. Внизу справа в VS Code выберите устройство.
3. **Run and Debug** (`Ctrl+Shift+D`) → выберите конфигурацию → **F5**.

Готовые конфигурации (`.vscode/launch.json`):

| Конфигурация | Что делает |
|---|---|
| Agro AI — Online (Android) | версия с Gemini и погодой |
| Agro AI — Offline (Android) | версия без интернета, только своя модель |
| Тесты (все) | 77 автотестов из папки `test/` (телефон не нужен) |
| Тест: путь фермера на телефоне | участок → полив → расход → итоги, на реальном телефоне |
| Тест: своя модель на телефоне | модель загружается и распознаёт |
| Python: проверить модель на полевых фото | точность на 204 фото PlantDoc |
| Python: обучение (быстрый пробный запуск) | короткое обучение на 200 фото (1 эпоха), чтобы показать, как идёт процесс |

Во время работы приложения: `r` в терминале — горячая перезагрузка (видно изменения за 1 секунду).

### Команды вручную

```bash
flutter run --flavor offline
```

```bash
flutter test
```

```bash
flutter analyze
```

```bash
flutter build apk --release --split-per-abi --flavor offline
```

## 4. Python: окружение для обучения

```bash
python -m venv .venv
```

```bash
.venv\Scripts\activate
```

```bash
pip install -r tools/train/requirements.txt
```

В VS Code: `Ctrl+Shift+P` → **Python: Select Interpreter** → `.venv`.

Полное обучение на обычном ноутбуке идёт много часов и требует много памяти, поэтому оно
запускается в облаке: GitHub → **Actions → train-model → Run workflow**
(примерно 2,5 часа, результат — файл `plant_disease.tflite`).
Локально удобно делать пробный запуск (конфигурация «обучение (быстрый пробный запуск)»)
и проверку модели (`eval_field.py`).

## 5. Где что лежит (чтобы открыть нужный файл)

| Что показать | Файл |
|---|---|
| Старт приложения, две версии | `lib/main.dart`, `lib/core/app_config.dart` |
| База данных SQLite | `lib/data/local/sqlite_farm_store.dart` |
| Логика хозяйства (сохранение, итоги) | `lib/data/repositories/farm_repository.dart` |
| Своя нейросеть в телефоне | `lib/services/offline/plant_classifier.dart`, `offline_diagnoser.dart` |
| Gemini | `lib/data/remote/gemini_api_client.dart`, `lib/services/ai_service.dart` |
| Резервные копии | `lib/services/backup_service.dart` |
| Тексты на тоҷикӣ/русском | `lib/core/localization/app_strings.dart` |
| Обучение модели | `tools/train/train.py`, `tools/train/extra_data.py` |
| Облачная сборка | `.github/workflows/*.yml` |
