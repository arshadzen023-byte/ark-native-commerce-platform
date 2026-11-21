# ark-native-commerce-platform

## Native WooCommerce payment checkout

The native checkout supports enabled WooCommerce COD and the ARK Native Bridge UPI QR configuration. UPI orders display the merchant VPA QR/deep link, collect the configured payer UPI ID, 12-digit UTR and optional/required JPG/PNG screenshot from Gallery, and submit the proof against the WooCommerce order key. The companion WordPress Bridge must be updated from PR #15 so UTR submission stays On Hold until a store administrator verifies payment. The Android release is version `1.0.3+83`. The app uses the existing `order-success.json` Lottie animation and displays the actual WooCommerce order reference/status.
