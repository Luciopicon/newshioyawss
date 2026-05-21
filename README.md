<div align="center">

# 🚀 XHTTP Relay ECO (VrcLIraniCore)

**نسخه سبک، امن و کم‌هزینه XHTTP Relay برای Vercel**

[![Runtime](https://img.shields.io/badge/Runtime-Rewrite_%2B_Node-black.svg?style=for-the-badge&logo=vercel)]()
[![Installer](https://img.shields.io/badge/Windows_Installer-Token_API_Mode-blue.svg?style=for-the-badge)]()
[![Profile](https://img.shields.io/badge/Recommended-FAST_PIPE_LEGACY-2ea44f.svg?style=for-the-badge)]()

**داستان این نسخه چیه؟**
<br>
🟥 **این نسخه برای این ساخته شده که دیپلوی روی Vercel تمیزتر، کم‌هزینه‌تر و قابل‌مدیریت‌تر بشه. الان دو مسیر اصلی داری: Rewrite mode برای کمترین هزینه و بدون Function، و Node mode برای وقتی که کنترل کامل‌تر، لاگ، throttle و ظرفیت بالاتر می‌خوای.**

📣 **جهت دریافت اطلاعات و نکات بیشتر به کانال تلگرامی من مراجعه کنید:** [B3hnamR@](https://t.me/B3hnamR).
📌 **نکته مهم:** لطفاً این راهنما رو تا انتها و با دقت بخونید تا موقع ستاپ کردن هیچ مشکلی براتون پیش نیاد.

**🔒 [برای ساخت اکانت، مطالعه این آموزش کاملاً ضروری است: Anti-Ban-Tutorial.md](./Anti-Ban-Tutorial.md)**

**توجه خیلی مهم:** این پروژه به‌خودی‌خود هیچ تاثیری در بن شدن اکانت ندارد؛ عامل بن فقط فرآیند ساخت اکانت است و این موضوع 100% تست شده.

**توجه خیلی مهم:** با ساخت رایگان اکانت پرو ترایال میتونید استفاده کنید ❤️
<br>
</div>

---

> ⚠️ **هشدار خیلی مهم**
> رفقا لطفا پروژه رو به هیچ‌وجه Fork نکنید. برای اینکه اکانتتون امن بمونه و شبکه‌تون شناسایی نشه، از بالای همین صفحه روی دکمه سبز **Code** کلیک کنید، بعد **Download ZIP** رو بزنید و حتماً برای دیپلوی از اینستالر ویندوزی پروژه استفاده کنید.

---

## ✨ تو نسخه جدید چه خبره؟

- 🔥 **مود پیشنهادی جدید:** `FAST_PIPE_LEGACY` مسیر پیش‌فرض Fast Pipe است؛ سریع، سبک، بدون Function Runtime و معمولاً سازگارتر برای اپ‌هایی مثل Instagram و YouTube.
- 🧠 **Node mode برای کنترل کامل:** اگر throttle، timeout، log و ظرفیت قابل‌تنظیم می‌خوای، دو پروفایل Node آماده و یک حالت Custom داری.
- 🔐 **توکن‌محور شدن اتصال به Vercel:** اسکریپت پروژه‌ها رو با Token/API می‌خونه، نه از روی لینک قدیمی پوشه `.vercel`.
- 🧹 **بازسازی لینک لوکال:** اگر فولدر قبلاً دیپلوی داشته باشه، اسکریپت لینک محلی رو از روی پروژه انتخاب‌شده دوباره می‌سازه تا اشتباهی روی پروژه قبلی نره.
- 🧾 **ENV Editor واقعی:** می‌تونی پروژه رو انتخاب کنی، ENVهای فعلی رو ببینی، چند مقدار رو تغییر بدی و آخرش یک Confirm بزنی تا Redeploy انجام بشه.
- 🌍 **Region چندتایی برای Node:** می‌تونی یک یا چند Function Region انتخاب کنی؛ مثل `arn1,fra1`.
- ⚙️ **Custom Build کامل:** Fluid Compute، Function CPU، Function Regions، Max Duration، timeout، throttle و log control قابل تنظیم دستی هستند.
- 🧪 **Health/Smoke ساده‌تر:** متن تست‌ها برای کاربر عادی قابل‌فهم‌تر شده؛ مخصوصاً خطاهای 400/404/500.
- 📡 **لاگ‌های قابل‌فهم:** لاگ‌ها و Live Logs الان خلاصه وضعیت، معنی خطا و قدم بعدی رو نشون میدن.
- 🛣️ **لندینگ استاتیک خودکار:** موقع Build یک Frontend استاتیک ساخته میشه تا دامنه فقط API-محور دیده نشه.

---

## 🧠 دو حالت اصلی پروژه

### ۱. FAST PIPE Rewrite

این حالت پیشنهادی برای شروعه و داخل اینستالر دو مدل دارد:

- `FAST PIPE LEGACY`: مدل پیشنهادی با `/path/(.*)` و `$1` برای سازگاری بیشتر.
- `FAST PIPE MODERN`: مدل رسمی‌تر Vercel با `/path/:path*`.

در این مدل Vercel فقط Rewrite انجام میده؛ یعنی درخواست از Edge ورسل رد میشه و مستقیم به `TARGET_DOMAIN` فوروارد میشه. اینجا کد Node پروژه اجرا نمی‌شود، پس دیتایی که میاد و میره عملاً بدون پردازش، بدون throttle و بدون کنترل نرم‌افزاری از سمت ما عبور می‌کنه.

خیلی ساده‌تر بگم: Rewrite مثل یک مسیر عبوریه. ورسل درخواست رو می‌گیره و به مقصد می‌فرسته؛ ما وسط مسیر نمی‌تونیم روی حجم، سرعت، تعداد کانکشن، timeout داخلی، لاگ Node یا منطق امنیتی Node کنترل بذاریم. تنها قفل اختیاری این مود همون شرط هدر `x-relay-key` داخل قانون Rewrite است، نه داخل کد Node.

در نتیجه در Rewrite mode:

- هیچ ENV روی Vercel ست نمی‌شود.
- Fluid Compute نیاز ندارد.
- Function Region نیاز ندارد.
- Function CPU نیاز ندارد.
- Function Max Duration نیاز ندارد.
- لاگ Node/Function ندارد، چون اصلاً Node Function اجرا نمی‌شود.
- اگر پسورد بذاری، قفل با هدر `x-relay-key` داخل `vercel.json` اعمال میشه.
- rewrite فقط روی همان مسیر انتخابی ساخته می‌شود، نه روی کل سایت. یعنی حالت strict path دارد.
- برای مسیر relay هدرهای `Cache-Control`، `CDN-Cache-Control` و `Vercel-CDN-Cache-Control` با مقدار no-store ست می‌شوند تا کش/CDN کمتر در مسیر تونل دخالت کند.
- محدودیت‌هایی مثل `MAX_INFLIGHT`، `MAX_UP_BPS`، `MAX_DOWN_BPS` و `UPSTREAM_TIMEOUT_MS` روی این مود اعمال نمی‌شوند.
- لاگ‌های حرفه‌ای و Live Logs اینستالر برای این مود skip می‌شوند، چون runtime ای وجود ندارد که لاگ تولید کند.
- هزینه Fluid/Function/CPU/Memory برای این مود صفر است.
- مصرفی که ممکنه ببینی مربوط به `Fast Data Transfer` و `Edge Requests` است، نه Fluid Compute.

در Fast Pipe، هدر پسورد اختیاری است. برای امنیت، مسیر را سخت و رندوم انتخاب کن؛ مثلاً:

```text
/api-b7f39xrelay
```

همین مسیر باید هم در اینستالر و هم در inbound سرور خارجی یکی باشد.

اگر موقع ساخت Fast Pipe مقدار `RELAY_KEY` وارد کنی، کلاینت حتماً باید این هدر رو بفرسته:

```json
{
  "headers": {
    "x-relay-key": "YourPassword"
  }
}
```

**مسیر در Rewrite mode چطور حساب میشه؟**

در Rewrite، همان path که کاربر روی دامنه Vercel می‌زند به `TARGET_DOMAIN` هم منتقل می‌شود. یعنی اگر کلاینت `/api` بزند، مقصد هم `/api` را دریافت می‌کند. پس مسیر کلاینت و مسیر اینباند مقصد را یکی بگیر تا دردسر نداشته باشی.

**اگر Instagram/YouTube روی Fast Pipe خوب نبود:**

- اول `FAST PIPE LEGACY` را تست کن، چون مدل خام‌تر rewrite معمولاً برای tunnel سازگاری بهتری دارد.
- سمت کلاینت Mux را هم ON با concurrency پایین مثل 4 یا 8 تست کن، هم OFF تست کن. برای ویدئو همیشه Mux بهتر نیست.
- اگر کلاینت heartbeat/keepalive دارد، 15 تا 20 ثانیه را تست کن. مقدار خیلی کم Edge Requests را بالا می‌برد.
- روی سرور خارجی BBR را فعال نگه دار.
- MTU مثل 1350 یا 1280 فقط تستی است؛ اگر route موبایل stall دارد ممکنه کمک کند، ولی راه‌حل قطعی نیست.

### ۲. Node Runtime

این حالت برای زمانی خوبه که کنترل دقیق‌تر می‌خوای:

- `TARGET_DOMAIN`
- `RELAY_PATH`
- `PUBLIC_RELAY_PATH`
- `MAX_INFLIGHT`
- `MAX_UP_BPS`
- `MAX_DOWN_BPS`
- `UPSTREAM_TIMEOUT_MS`
- کنترل لاگ‌ها
- Function Region
- Fluid Compute
- Function CPU
- Function Max Duration

در Node mode لاگ و Live Log معنی دارد و ابزارهای دیباگ کامل‌تر کار می‌کنند.

تفاوت اصلی Node با Rewrite اینه که اینجا درخواست وارد کد `api/index.js` میشه. پس پروژه می‌تونه مسیر رو چک کنه، متدهای اضافه رو ببنده، هدرها رو تمیز کنه، `x-relay-key` رو داخل کد بررسی کنه، سرعت آپلود/دانلود رو محدود کنه، timeout بذاره، تعداد درخواست همزمان رو کنترل کنه و لاگ قابل‌فهم تولید کنه.

پس اگر کنترل، محدودیت سرعت، ظرفیت، لاگ و دیباگ می‌خوای، باید Node mode بزنی. اگر کمترین هزینه و عبور مستقیم می‌خوای، Rewrite mode مناسب‌تره.

---

## 🪟 نصب خودکار و بی‌دردسر روی ویندوز

برای رفقایی که نمی‌خوان با ترمینال درگیر بشن، دو فایل آماده شده:

- `Run-Deploy-Windows.bat`
- `Deploy-Windows.ps1`

**چطور استفاده کنیم؟**

۱. فایل ZIP پروژه رو Extract کن.
۲. فیلترشکن رو روی **TUN Mode** یا تونل کل سیستم روشن کن.
۳. روی `Run-Deploy-Windows.bat` دابل‌کلیک کن.
۴. اگر پرسید Auth Mode، گزینه Token mode رو انتخاب کن.
۵. Token Vercel رو وارد کن.
۶. اگر پروژه موجود داشتی، از لیست انتخاب کن؛ اگر نداشتی، `Deploy as NEW project` رو بزن.

**Token mode چرا پیشنهاد میشه؟**

چون اسکریپت پروژه‌ها رو مستقیم از Vercel API می‌خونه. این یعنی حتی اگر داخل فولدر `.vercel` از قبل یک لینک قدیمی وجود داشته باشه، اسکریپت نباید کورکورانه از اون استفاده کنه. پروژه از روی Token انتخاب میشه و لینک لوکال بعدش دوباره ساخته میشه.

در Token mode می‌تونی توکن رو امن داخل همین پوشه ذخیره کنی:

```text
.vercel-token.dpapi
```

این فایل با DPAPI ویندوز ذخیره میشه و برای همین کاربر/سیستم فعلی قابل استفاده است.

**چند کار مهمی که اسکریپت خودش انجام میده:**

- اگر `npm` یا `vercel` نصب نباشه، تلاش می‌کنه نصب/آماده‌شون کنه.
- پروژه‌ها رو با Token/API می‌خونه و اگر پروژه موجود باشه، انتخابش می‌کنی.
- لینک محلی `.vercel/project.json` رو از روی پروژه انتخاب‌شده بازسازی می‌کنه.
- برای Node mode، ENVهای production رو ست می‌کنه.
- برای Rewrite mode، `vercel.json` موقت می‌سازه و بعد از Deploy برمی‌گردونه.
- `Vercel Authentication` پروژه رو اگر دسترسی API بده خاموش می‌کنه تا دامنه عمومی درست باز بشه.
- قبل از Deploy، بخشی از metadata مثل `package.json` و `vercel.json` رو موقت randomize می‌کنه و بعدش برمی‌گردونه.

---

## 🎛️ مودهای دیپلوی داخل اینستالر

### `[1] FAST PIPE LEGACY`

نام داخلی پروفایل: `FAST_PIPE_LEGACY`

**Rewrite (RECOMMENDED / NO FLUID COST / BEST COMPATIBILITY)**

بهترین گزینه برای شروع و مخصوصاً برای اپ‌هایی که request زیاد و ریز دارند. سریع و سبک است، Vercel Function مصرف نمی‌کند، header پسورد لازم ندارد و باید با یک `RELAY_PATH` سخت/رندوم استفاده شود.

مراحلش ساده است:

۱. Scope رو انتخاب می‌کنی.
۲. Preset اول یعنی `FAST PIPE LEGACY` رو انتخاب می‌کنی.
۳. `TARGET_DOMAIN` رو وارد می‌کنی.
۴. `RELAY_PATH` سخت و رندوم وارد می‌کنی، مثل `/api-b7f39xrelay`.
۵. همان path را در inbound سرور خارجی هم می‌گذاری.
۶. Confirm می‌کنی و Deploy انجام میشه.

### `[2] FAST PIPE MODERN`

نام داخلی پروفایل: `FAST_PIPE_MODERN`

**Rewrite (NO FLUID COST / OFFICIAL PATH SYNTAX)**

این مدل از syntax رسمی Vercel با `:path*` استفاده می‌کند. اگر Legacy روی یک مسیر خاص خوب جواب نداد، این مدل را تست کن.

در هر دو Fast Pipe، `RELAY_KEY` اختیاری است. خالی بگذاری یعنی بدون هدر؛ مقدار بدهی یعنی کلاینت باید `x-relay-key` را بفرستد.

### `[3] FAST PIPE SIMPLE`

نام داخلی پروفایل: `FAST_PIPE_SIMPLE`

**Rewrite (SINGLE RULE / NO FLUID COST)**

این مدل فقط یک rule با syntax قدیمی‌تر می‌سازد:

```json
{ "source": "/api/(.*)", "destination": "https://server:port/api/$1" }
```

در این مدل headerهای no-store، base path جدا، fallback landing و `x-relay-key` ساخته یا پرسیده نمی‌شود.

### `[4] FAST PIPE SIMPLE MODERN`

نام داخلی پروفایل: `FAST_PIPE_SIMPLE_MODERN`

**Rewrite (SINGLE RULE / MODERN SYNTAX / NO FLUID COST)**

این مدل فقط یک rule با syntax رسمی `:path*` می‌سازد:

```json
{ "source": "/api/:path*", "destination": "https://server:port/api/:path*" }
```

در این مدل هم headerهای no-store، base path جدا، fallback landing و `x-relay-key` ساخته یا پرسیده نمی‌شود.

### `[5] BALANCED`

نام داخلی پروفایل: `BALANCED_LOW_TIMEOUT`

Node + Fluid ON برای استفاده متعادل.

```text
MAX_INFLIGHT=256
MAX_UP_BPS=5242880
MAX_DOWN_BPS=5242880
UPSTREAM_TIMEOUT_MS=60000
Function Max Duration=800
Function CPU=standard
```

### `[6] MAX CONN`

نام داخلی پروفایل: `MAX_STABILITY_HIGH_CONN`

Node + Fluid ON برای ظرفیت اتصال بالاتر.

```text
MAX_INFLIGHT=512
MAX_UP_BPS=10485760
MAX_DOWN_BPS=10485760
UPSTREAM_TIMEOUT_MS=60000
Function Max Duration=800
Function CPU=standard
```

### `[7] CUSTOM`

نام داخلی پروفایل: `CUSTOM_BUILD`

برای کسی که می‌خواد همه چیز رو خودش تنظیم کنه.

داخل Custom Build می‌تونی این موارد رو تعیین کنی:

- Runtime: `node` یا `rewrite`
- Fluid Compute: روشن یا خاموش
- Function Regions: یک یا چند ریجن
- Function CPU
- `MAX_INFLIGHT`
- `MAX_UP_BPS`
- `MAX_DOWN_BPS`
- `UPSTREAM_TIMEOUT_MS`
- Function Max Duration

**Function CPU وقتی Fluid روشنه:**

- `Standard`: یک vCPU و 2GB Memory
- `Performance`: دو vCPU و 4GB Memory

**Function CPU وقتی Fluid خاموشه:**

- `Basic`: حدود 0.6 vCPU و 1GB Memory
- `Standard`: حدود 1 vCPU و 1.7GB Memory
- `Performance`: حدود 1.7 vCPU و 3GB Memory

**ریجن‌های آماده داخل اینستالر:**

| کد | منطقه | توضیح |
| :--- | :--- | :--- |
| `cdg1` | Paris, France | Europe West / eu-west-3 |
| `arn1` | Stockholm, Sweden | Europe North / eu-north-1 |
| `dub1` | Dublin, Ireland | Europe West / eu-west-1 |
| `lhr1` | London, United Kingdom | Europe West / eu-west-2 |
| `fra1` | Frankfurt, Germany | Europe Central / eu-central-1 |
| `iad1` | Washington, D.C., USA | US East / us-east-1 |
| `dxb1` | Dubai, United Arab Emirates | Middle East Central / me-central-1 |

برای چند ریجن، می‌تونی اینجوری وارد کنی:

```text
arn1,fra1
```

---

## 📋 پنل مدیریت بعد از انتخاب پروژه

بعد از اینکه پروژه انتخاب یا ساخته شد، منوی مدیریت میاد:

```text
[1] Select project from Vercel list
[2] Redeploy selected project
[3] Update production ENV vars (choose project + editor)
[4] List recent deployments (selected project)
[5] Deploy as NEW project
[6] Run health + smoke checks
[7] Show readable logs (summary + fixes)
[8] Run load-test lite
[9] ENV drift detector
[10] Profile benchmark runner
[11] Live readable logs (press Q to stop)
[12] View deployment ENV config (full)
[13] Delete Project (choose from list)
[14] Billing / Usage monitor (REST API)
[15] Exit
```

**گزینه 3 دقیقاً چیکار می‌کنه؟**

این گزینه پروژه‌ها رو نشون میده، پروژه رو انتخاب می‌کنی، ENVهای فعلی production رو می‌بینی، بعد هر چندتا ENV خواستی انتخاب و مقدار جدید میدی. آخرش با Confirm نهایی تغییرات اعمال میشه و Redeploy میره.

**گزینه 7 و 11 برای کدوم مودهاست؟**

برای Node mode.

اگر پروژه با یکی از حالت‌های `FAST_PIPE_REWRITE_*` ساخته شده باشه، لاگ و Live Log مربوط به Node وجود نداره و اسکریپت هم درست skip می‌کنه.

**گزینه 14 چیه؟**

این گزینه از REST API رسمی Vercel یعنی `/v1/billing/charges` استفاده می‌کنه و مصرف اکانت/تیم رو از روی Billing API می‌خونه. خروجی به شکل ساده نشون داده میشه، مثلاً:

```text
Fast Data Transfer: 23.00 GB / 100 GB | Charge $0.00
Edge Requests: 2.17M / 1M | Charge $0.00
Fluid Active CPU: 18h 55m / 4h | Charge $0.00
```

برای بعضی ردیف‌ها، Vercel داخل charge row فقط مقدار مصرف و هزینه رو میده، نه سقف پلن رو. برای همین عدد سمت راست مثل `100 GB` یا `1M` طبق allowance شناخته‌شده Pro نمایش داده میشه تا کاربر بفهمه نسبت مصرف چقدره.

برای Rewrite mode این گزینه خیلی کاربردیه، چون سریع می‌فهمی مصرف Fluid/Function واقعاً صفر مونده و فقط `Fast Data Transfer` / `Edge Requests` بالا رفته یا نه.

**گزینه 13 چطور حذف می‌کنه؟**

`Delete Project` اول دوباره لیست پروژه‌های Vercel رو از Token/API میاره. پروژه‌ای که می‌خوای حذف کنی رو از لیست انتخاب می‌کنی، بعد برای امنیت باید اول `DELETE` و بعد نام دقیق پروژه رو تایپ کنی. بعد از حذف، لیست پروژه‌ها دوباره refresh میشه تا بتونی یک پروژه دیگه انتخاب کنی یا `Deploy as NEW project` بزنی.

---

## 🔧 ENVها در Node mode

اگر Node Runtime استفاده می‌کنی، ENVهای مهم این‌ها هستند:

| متغیر | وضعیت | دیفالت هسته | توضیح |
| :--- | :---: | :---: | :--- |
| `TARGET_DOMAIN` | 🔴 اجباری | - | آدرس سرور مقصد، مثل `https://domain.com:443` |
| `RELAY_PATH` | 🔴 اجباری | - | مسیر واقعی اینباند روی سرور خارج، مثل `/api` |
| `PUBLIC_RELAY_PATH` | ⚪ اختیاری | `/api` | مسیر عمومی روی دامنه Vercel |
| `LANDING_TEMPLATE` | ⚪ اختیاری | random | اگر ست بشه، تمپلیت ثابت انتخاب میشه |
| `AUTO_FRONTEND` | ⚪ اختیاری | `1` | اگر `0` بشه، تولید لندینگ خودکار خاموش میشه |
| `UPSTREAM_TIMEOUT_MS` | ⚪ اختیاری | `25000` | سقف انتظار برای upstream |
| `MAX_INFLIGHT` | ⚪ اختیاری | `128` | سقف درخواست همزمان داخل هر instance |
| `MAX_UP_BPS` | ⚪ اختیاری | `2621440` | سقف آپلود بر حسب byte/sec |
| `MAX_DOWN_BPS` | ⚪ اختیاری | `2621440` | سقف دانلود بر حسب byte/sec |
| `SUCCESS_LOG_SAMPLE_RATE` | ⚪ اختیاری | `0` | نرخ نمونه‌گیری لاگ موفق‌ها |
| `SUCCESS_LOG_MIN_DURATION_MS` | ⚪ اختیاری | `3000` | فقط موفق‌های کندتر از این مقدار لاگ می‌شن |
| `ERROR_LOG_MIN_INTERVAL_MS` | ⚪ اختیاری | `5000` | فاصله حداقلی بین لاگ خطاها |
| `UPSTREAM_DNS_ORDER` | ⚪ اختیاری | `ipv4first` | ترتیب DNS برای اتصال به upstream |
| `RELAY_KEY` | ⚪ اختیاری | - | اگر دستی ست بشه، کلاینت باید `x-relay-key` بفرسته |

> ℹ️ **نکته:** در Rewrite mode این ENVها deploy نمی‌شن و نیاز هم نیستند.

---

## 🧪 Health و Smoke Check یعنی چی؟

اینستالر بعد از Deploy می‌تونه چند تست ساده بگیره.

**در Node mode:**

- Root باید بالا باشد.
- مسیر اشتباه معمولاً باید `404` بده.
- متد اشتباه معمولاً باید `405` بده.
- مسیر درست Relay نباید `404` باشد.
- اگر `400` دیدی، همیشه بد نیست؛ ممکنه یعنی مسیر پیدا شده ولی تست خام، فریم واقعی کلاینت نیست.
- اگر `500/502/504` دیدی، معمولاً مشکل از مقصد، پورت، timeout یا فشار runtime است.

**در Rewrite mode:**

تست‌های عمیق Node skip می‌شوند، چون Node Function نداریم. اگر برای درخواست‌های مرورگری `404` دیدی، الزاماً یعنی کانفیگ خراب نیست؛ ممکنه مقصد به probe ساده جواب 404 بده.

---

## 📡 لاگ‌ها و Live Logs

در نسخه جدید، لاگ‌ها برای کاربر عادی‌تر نوشته شدند.

به جای اینکه فقط چیزی مثل این ببینی:

```text
st=500 m=GET path=/api
```

الان خلاصه می‌بینی:

- Status چی بوده.
- معنی ساده خطا چیه.
- قدم بعدی چیه.
- آیا مشکل از path، key، timeout، DNS، target server یا ظرفیت است.

نمونه معنی‌ها:

| وضعیت | معنی ساده |
| :--- | :--- |
| `200` | درخواست موفق بوده |
| `400` | مسیر جواب داده ولی probe یا فرمت درخواست کامل نبوده |
| `403` | کلید `x-relay-key` اشتباه یا ارسال نشده |
| `404` | Path اشتباه است |
| `405` | متد اشتباه است و این معمولاً برای تست‌ها خوبه |
| `429/503` | فشار یا تعداد درخواست زیاد است |
| `500/502/504` | مشکل سمت مقصد، پورت، timeout یا runtime |

برای دیباگ:

۱. گزینه 7 رو بزن و window مثلاً 5 یا 30 دقیقه بده.
۲. اگر می‌خوای همزمان تست بزنی، گزینه 11 رو باز کن.
۳. کلاینت رو روشن کن و یک تست اتصال بزن.
۴. اگر Rewrite mode هستی، دنبال Node logs نگرد؛ وجود نداره.

---

## 🧮 چطور سرعت رو به بایت حساب کنم؟

`MAX_UP_BPS` و `MAX_DOWN_BPS` بر اساس بایت بر ثانیه هستند.

فرمول:

```text
Mbps × 131072 = bytes/sec
```

چند مقدار آماده:

| سرعت | مقدار |
| :--- | :--- |
| 10 Mbps | `1310720` |
| 20 Mbps | `2621440` |
| 40 Mbps | `5242880` |
| 80 Mbps | `10485760` |

---

## 💻 نمونه کانفیگ کلاینت

نمونه کلی:

```text
vless://UUID-HERE@vercel.com:443?encryption=none&security=tls&sni=vercel.com&fp=chrome&alpn=h2&insecure=0&allowInsecure=0&type=xhttp&host=YOUR-VERCEL-DOMAIN&path=%2Fapi&mode=auto#XHTTP-ECO
```

یادت نره:

- `host` باید دامنه Vercel پروژه خودت باشه.
- `path` باید با مسیر عمومی پروژه یکی باشه.
- `%2Fapi` یعنی `/api`.
- اگر Rewrite Secure با پسورد ساختی، در بخش XHTTP Extra هدر `x-relay-key` رو هم وارد کن.

---

## 🛠️ معنی ارورها

- `200`: همه‌چی خوبه.
- `400`: مسیر جواب داده ولی درخواست تست/کلاینت ممکنه کامل نباشه.
- `403`: پسورد یا هدر `x-relay-key` اشتباهه.
- `404`: مسیر اشتباهه؛ `RELAY_PATH` یا Path کلاینت رو چک کن.
- `405`: متد اشتباهه؛ برای بعضی smoke testها طبیعی و خوبه.
- `429`: درخواست زیاد در زمان کم.
- `500`: ENV یا runtime مشکل دارد، یا کد به تنظیمات لازم نرسیده.
- `502`: Relay به سرور مقصد وصل نشده.
- `503`: سقف همزمانی یا فشار ترافیک.
- `504`: timeout؛ مقصد دیر جواب داده یا در دسترس نیست.

---

## 🧩 لندینگ رندم چطور کار می‌کنه؟

تمپلیت‌ها داخل این مسیر هستند:

```text
templates/landing/
```

هر Build یک تمپلیت انتخاب می‌کند و خروجی استاتیک می‌سازد. اگر `LANDING_TEMPLATE` ست نکرده باشی، انتخاب به‌صورت رندم انجام میشه.

توکن‌های قابل جایگزینی داخل تمپلیت‌ها:

```text
{{BUILD_CODE}}
{{PUBLIC_RELAY_PATH}}
{{RELAY_PATH}}
{{GENERATED_AT}}
{{TEMPLATE_NAME}}
```

---

## 🧾 Build Profile Summary

بعد از Deploy، اسکریپت یک خلاصه قابل اشتراک از تنظیمات می‌سازه، مثل:

```text
build-profile-20260507-153950.txt
```

داخلش اطلاعات حساس مثل مقدار واقعی پسورد نوشته نمی‌شود؛ فقط مشخص می‌کند که کلید ست شده یا نه. این فایل برای این خوبه که بعداً بفهمی دقیقاً با چه پروفایلی Deploy کردی.

---

## 💸 هزینه روی Vercel

اگر دنبال کمترین هزینه هستی، اول `FAST_PIPE_LEGACY` رو تست کن، چون Function Runtime ندارد و ENV/CPU/Duration هم برایش معنی ندارد. اگر syntax رسمی‌تر Vercel می‌خواهی، بعدش `FAST_PIPE_MODERN` را تست کن.

**هزینه در Rewrite mode:**

در Rewrite mode هیچ Function ای اجرا نمی‌شود. یعنی:

- Fluid Compute: صفر
- Function CPU: صفر
- Function Memory: صفر
- Function Max Duration: بی‌معنی و بدون هزینه
- Observability/Node Logs: عملاً لاگ Node نداری

اما این به معنی «هیچ مصرفی در کل اکانت» نیست. چیزی که ممکنه مصرف بشه این‌هاست:

- `Fast Data Transfer`
- `Edge Requests`

پس اگر جایی در داشبورد Vercel مصرف دیدی، برای Rewrite معمولاً از جنس انتقال دیتا و درخواست‌های Edge است، نه Fluid.

اگر Node mode استفاده می‌کنی، هزینه بیشتر از این بخش‌ها میاد:

- Function Invocations
- Active CPU / Fluid Compute
- Provisioned Memory
- Fast Origin Transfer
- Observability / Logs

برای همین در Node presetها لاگ‌های موفق محدود شدند و خطاها هم rate-limit دارند تا لاگ بی‌خودی زیاد نشه.

---

## راهنمای دستی خیلی خلاصه

اگر نمی‌خوای از اسکریپت ویندوز استفاده کنی:

```bash
npm i -g vercel
vercel login
vercel deploy
```

بعد داخل Dashboard پروژه، ENVهای Node mode رو ست کن و Redeploy بزن.

برای Rewrite mode پیشنهاد جدی اینه از اسکریپت استفاده کنی، چون `vercel.json` موقت و مسیرها رو خودش درست می‌سازه.

---

## 💖 تشکر ویژه و منبع اصلی

باید یادی کنیم از منبع اصلی این حرکت؛ این پروژه در واقع فورک و توسعه‌یافته از ایده‌های ناب و زحمات بچه‌های کانال تلگرامی [Avaco Cloud](https://t.me/avaco_cloud) هست. دم تیم آواکو کلاود گرم که این مسیر رو برای وب‌گردی آزاد و توسعه ابزارهای این‌چنینی باز کردن. حتماً به کانالشون سر بزنید و از محتواشون حمایت کنید! 🤝

---

## ☕ حمایت از پروژه

اگر این پروژه براتون مفید بود و دوست داشتید از ادامه توسعه‌اش حمایت کنید، می‌تونید از آدرس‌های زیر استفاده کنید:

**Tron (TRX) / USDT (TRC-20):**

```text
TTfYReJ7aJEvx4CfwgtY3UV8hJHXTrTwnn
```

**BNB / USDT (BEP-20):**

```text
0x25CAc03F80C12FFc30D8264e4b90423AFfA2E6Ac
```

---

## License

MIT
