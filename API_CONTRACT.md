# GlowHit Flutter ↔ ARK Native Commerce Bridge API Contract

Store origin: `https://pluginstore.shop`

The app intentionally uses two official WooCommerce interfaces plus one ARK bridge namespace. These are not duplicate implementations: WooCommerce Store API owns the cart, shipping calculation and checkout lifecycle; ARK Native Commerce Bridge owns customer identity and native-app account/payment support.

## ARK Native Commerce Bridge — `/wp-json/ark-native/v1`

| Flutter action | Method | Route |
|---|---:|---|
| Bridge health / deployment check | GET | `/health` |
| Customer sign-in | POST | `/auth/login` |
| Legacy sign-in fallback (only after 404) | POST | `/customer/login` |
| Customer logout | POST | `/customer/logout` |
| Read customer profile | GET | `/customer/me` |
| Update customer profile | PUT | `/customer/me` |
| List saved addresses | GET | `/customer/addresses` |
| Save / update saved address | POST | `/customer/addresses` |
| Delete saved address | DELETE | `/customer/addresses?id=...` |
| List customer orders | GET | `/customer/orders` |
| Order detail | GET | `/customer/orders/{id}` |
| Cancel order | POST | `/customer/orders/{id}/cancel` |
| Request return | POST | `/customer/orders/{id}/return` |
| Link checkout order to signed-in account | POST | `/orders/attach` |
| Read native payment configuration | GET | `/payment/config` |
| Submit UPI UTR + screenshot | POST multipart | `/payment/upi-submit` |

All customer routes except login require `Authorization: Bearer <JWT>`. Order linking verifies the WooCommerce order key and requires the checkout billing email to match the signed-in account email. UPI proof is not treated as a settled payment; the order remains awaiting store-owner verification.

## WooCommerce Store API — `/wp-json/wc/store/v1`

| Flutter action | Method | Route |
|---|---:|---|
| Product catalogue | GET | `/products` |
| Read cart / session | GET | `/cart` |
| Add cart item | POST | `/cart/add-item` |
| Update cart item | POST | `/cart/update-item` |
| Remove cart item | POST | `/cart/remove-item` |
| Apply customer billing/shipping address and calculate rates | POST | `/cart/update-customer` |
| Select shipping rate | POST | `/cart/select-shipping-rate` |
| Read checkout fields, totals and payment methods | GET | `/checkout` |
| Create WooCommerce order | POST | `/checkout` |

Store API requests retain WooCommerce Cart-Token / Nonce session headers. The ARK plugin must not replace or proxy these WooCommerce core endpoints.

## Release verification

GitHub Actions runs `flutter analyze --no-fatal-infos`, `flutter test`, and `flutter build apk --release`. The WordPress plugin has its own PHP syntax, API-route contract and ZIP packaging workflow in the `pluginstore-wordpress` repository.
