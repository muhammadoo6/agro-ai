# Agro AI

Ёрдамчии рақамии деҳқони тоҷик. Flutter-барнома барои Android (iOS дар оянда).

## Имкониятҳо

| Бахш | Чӣ мекунад |
|---|---|
| **Асосӣ** | Омори хоҷагӣ, обёрии наздик, амалҳои зуд |
| **Қитъаҳо** | Қитъаҳо, мавсимҳои кишт бо пешрафт, таърихи обёрӣ ва ҳосил |
| **Скан** | Акси растанӣ → ташхиси AI (Claude) ё маслиҳати офлайн аз донишнома |
| **Обёрӣ** | Сабти обёрӣ, банақшагирӣ ва ёдраскунӣ (огоҳинома дар соати 07:00) |
| **Дафтар** | Хароҷот/даромад, ҳосил (бо сабти худкори даромад), хулоса аз рӯи давра, категория ва қитъа |
| **Донишнома** | 8 зироат: пахта, гандум, картошка, помидор, пиёз, бодиринг, зардолу, харбуза |
| **Танзимот** | Забон (тоҷикӣ/русӣ), мавзӯъ, калиди AI, огоҳинома, нусхаи эҳтиётӣ, пок кардан |

Ҳамаи маълумот дар телефон нигоҳ дошта мешавад (бе интернет кор мекунад).
Интернет танҳо барои скани AI лозим аст.

## Сохтор

```
lib/
  main.dart, app.dart          оғоз ва MaterialApp
  core/                        theme, navigation, localization, validation, utils, app_scope
  models/                      plot, crop_cycle, irrigation, transaction, harvest, plant_scan
  data/local/                  LocalStore (файлҳои JSON, сабти атомӣ)
  data/remote/                 ClaudeApiClient (Messages API, HTTP)
  data/repositories/           FarmRepository, SettingsRepository
  services/                    ai_service, notification_service, backup_service
  features/                    home, plots, plant_scan, irrigation, farm_diary, knowledge, settings
  shared/widgets/              ҷузъҳои умумӣ
assets/data/crop_guides_tg.json  донишномаи тоҷикӣ
test/                          санҷишҳои воҳидӣ ва виҷетӣ
integration_test/              ҷараёни пурра дар дастгоҳ
```

## Фармонҳо

```bash
flutter pub get
flutter analyze
flutter test
flutter test integration_test   # дастгоҳ ё эмулятор лозим
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
```

## AI

Скан аз модели `claude-opus-5-5` тавассути `https://api.anthropic.com/v1/messages`
истифода мебарад (ҷавоби сохторёфтаи JSON). Калиди API дар **Танзимот** ворид
карда мешавад ва танҳо дар телефон нигоҳ дошта мешавад; ба нусхаи эҳтиётӣ дохил намешавад.

> Барои истифодаи оммавӣ калидро дар телефон нигоҳ доштан тавсия дода намешавад —
> сервери миёнарав (proxy) созед, ки калидро нигоҳ дорад ва дархостҳоро маҳдуд кунад.
> Ҷойи он: `lib/data/remote/` (`ClaudeApiClient(baseUrl: ...)`).

## Маҳдудиятҳои маълум

- Material Flutter тарҷумаи тоҷикӣ надорад: тақвим ва тугмаҳои системавӣ бо русӣ.
- Минтақаи вақти огоҳиномаҳо: `Asia/Dushanbe`.
- Аксҳои скан ба нусхаи эҳтиётӣ дохил намешаванд (танҳо натиҷаҳо).
