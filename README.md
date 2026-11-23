# GlowHit Native Commerce App

Flutter-native WooCommerce shopping app for https://pluginstore.shop.

## Single WordPress API dependency

Install and activate **ARK GlowHit Native Commerce Bridge 2.1.0** from the companion repository:
https://github.com/arshadzen023-byte/pluginstore-wordpress/tree/main/wp-content/plugins/ark-native-api-bridge

The app's customer authentication, profile, saved addresses, order history/details/cancellation, wishlist, payment configuration and UPI proof submission use the unified `ark-native/v1` API in that plugin.

The legacy `wordpress-addon/ark-native-customer-api` implementation has been removed. Do not install or enable a second customer API plugin; duplicate route registration and competing token stores can cause inconsistent login/address/order behavior.

## App flows

- App launch validates the saved customer session. Signed-out customers see the login landing page; successful sign-in opens Home.
- Checkout: Summary → Address → Payment → Order Received.
- Summary: live WooCommerce cart items, quantity controls, remove item and totals.
- Address: saved customer address cards, add/select address, sync to customer account, update shipping destination and calculate/select a WooCommerce shipping rate.
- Payment: enabled WooCommerce methods (including COD) and the configured merchant UPI QR. UPI proof submission sends the UTR and configured screenshot; an uploaded UTR is not treated as proof of settled payment and remains awaiting store verification.
- My Orders: customer orders, item details and images, amount, payment method, delivery address, status and cancellation request.

## Build and validation

GitHub Actions runs Flutter Analyze, widget tests and Android release APK build. The installable APK is published as a workflow artifact and a prerelease for the configured release branch.

## Production verification

A green GitHub build validates source and compilation; it does not prove production API reachability. Confirm the bridge health endpoint on the live store:
`https://pluginstore.shop/wp-json/ark-native/v1/health`

If the store returns HTTP 403 or an HTML firewall page, hosting/WAF rules must be checked separately. Do not bypass security controls or hardcode secrets in the app.
