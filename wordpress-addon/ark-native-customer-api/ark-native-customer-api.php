<?php
/**
 * Plugin Name: ARK Native Customer API Bridge
 * Description: Authenticated customer sessions and account endpoints for the GlowHit native shopping app.
 * Version: 1.0.0
 * Requires Plugins: woocommerce
 * Requires PHP: 7.4
 * License: GPL-2.0-or-later
 */
defined('ABSPATH') || exit;

final class ARK_Native_Customer_API_Bridge {
    const NS = 'ark-native/v1';
    const TOKEN_HASH = '_ark_native_api_token_hash';
    const TOKEN_EXP = '_ark_native_api_token_exp';

    public function __construct() {
        add_action('rest_api_init', [$this, 'routes']);
    }

    public function routes() {
        register_rest_route(self::NS, '/customer/login', [
            'methods' => 'POST', 'callback' => [$this, 'login'], 'permission_callback' => '__return_true',
        ]);
        register_rest_route(self::NS, '/customer/logout', [
            'methods' => 'POST', 'callback' => [$this, 'logout'], 'permission_callback' => [$this, 'authenticate'],
        ]);
        register_rest_route(self::NS, '/customer/me', [
            ['methods' => 'GET', 'callback' => [$this, 'profile'], 'permission_callback' => [$this, 'authenticate']],
            ['methods' => 'PUT', 'callback' => [$this, 'update_profile'], 'permission_callback' => [$this, 'authenticate']],
        ]);
        register_rest_route(self::NS, '/customer/orders', [
            'methods' => 'GET', 'callback' => [$this, 'orders'], 'permission_callback' => [$this, 'authenticate'],
        ]);
        register_rest_route(self::NS, '/customer/downloads', [
            'methods' => 'GET', 'callback' => [$this, 'downloads'], 'permission_callback' => [$this, 'authenticate'],
        ]);
        register_rest_route(self::NS, '/customer/addresses', [
            ['methods' => 'GET', 'callback' => [$this, 'addresses'], 'permission_callback' => [$this, 'authenticate']],
            ['methods' => 'POST', 'callback' => [$this, 'save_address'], 'permission_callback' => [$this, 'authenticate']],
            ['methods' => 'DELETE', 'callback' => [$this, 'delete_address'], 'permission_callback' => [$this, 'authenticate']],
        ]);
    }

    private function user_id($request) {
        return (int) $request->get_param('_ark_user_id');
    }

    public function authenticate($request) {
        $header = $request->get_header('authorization');
        if (!$header || !preg_match('/^Bearer\\s+(.+)$/i', $header, $match)) {
            return new WP_Error('ark_auth_required', 'Please sign in to your customer account.', ['status' => 401]);
        }
        $token = trim($match[1]);
        $users = get_users(['meta_key' => self::TOKEN_HASH, 'number' => 100, 'fields' => 'all']);
        foreach ($users as $user) {
            $hash = get_user_meta($user->ID, self::TOKEN_HASH, true);
            $expires = (int) get_user_meta($user->ID, self::TOKEN_EXP, true);
            if ($hash && $expires > time() && wp_check_password($token, $hash, $user->ID)) {
                $request->set_param('_ark_user_id', (int) $user->ID);
                return true;
            }
        }
        return new WP_Error('ark_session_expired', 'Your session has expired. Please sign in again.', ['status' => 401]);
    }

    public function login($request) {
        $data = $request->get_json_params();
        $login = sanitize_text_field($data['email_or_username'] ?? '');
        $password = (string) ($data['password'] ?? '');
        if ($login === '' || $password === '') {
            return new WP_Error('ark_login_fields', 'Enter your email or username and password.', ['status' => 400]);
        }
        $user = wp_authenticate($login, $password);
        if (is_wp_error($user)) {
            return new WP_Error('ark_login_failed', 'Incorrect username/email or password.', ['status' => 401]);
        }
        if (!class_exists('WooCommerce')) {
            return new WP_Error('ark_woocommerce_missing', 'WooCommerce is required.', ['status' => 503]);
        }
        $token = bin2hex(random_bytes(32));
        update_user_meta($user->ID, self::TOKEN_HASH, wp_hash_password($token));
        update_user_meta($user->ID, self::TOKEN_EXP, time() + (30 * DAY_IN_SECONDS));
        return rest_ensure_response([
            'session' => ['token' => $token, 'expires_in' => 30 * DAY_IN_SECONDS],
            'customer' => ['id' => (int) $user->ID, 'email' => $user->user_email, 'name' => $user->display_name],
        ]);
    }

    public function logout($request) {
        $id = $this->user_id($request);
        delete_user_meta($id, self::TOKEN_HASH);
        delete_user_meta($id, self::TOKEN_EXP);
        return rest_ensure_response(['logged_out' => true]);
    }

    public function profile($request) {
        $id = $this->user_id($request);
        $user = get_userdata($id);
        $customer = new WC_Customer($id);
        return rest_ensure_response([
            'id' => $id, 'email' => $user->user_email, 'display_name' => $user->display_name,
            'first_name' => $customer->get_first_name(), 'last_name' => $customer->get_last_name(),
            'billing' => $customer->get_billing(), 'shipping' => $customer->get_shipping(),
        ]);
    }

    public function update_profile($request) {
        $id = $this->user_id($request);
        $data = $request->get_json_params();
        $user_data = ['ID' => $id];
        if (isset($data['display_name'])) $user_data['display_name'] = sanitize_text_field($data['display_name']);
        if (isset($data['email'])) {
            $email = sanitize_email($data['email']);
            if (!is_email($email)) return new WP_Error('ark_invalid_email', 'Enter a valid email address.', ['status' => 400]);
            $user_data['user_email'] = $email;
        }
        $updated = wp_update_user($user_data);
        if (is_wp_error($updated)) return $updated;
        $customer = new WC_Customer($id);
        foreach (['first_name', 'last_name', 'billing_phone'] as $key) {
            if (isset($data[$key])) {
                $method = 'set_' . $key;
                $customer->$method(sanitize_text_field($data[$key]));
            }
        }
        $customer->save();
        return $this->profile($request);
    }

    public function orders($request) {
        $orders = wc_get_orders(['customer_id' => $this->user_id($request), 'limit' => 50, 'orderby' => 'date', 'order' => 'DESC']);
        $result = [];
        foreach ($orders as $order) {
            $lines = [];
            foreach ($order->get_items() as $item) {
                $lines[] = ['name' => $item->get_name(), 'quantity' => $item->get_quantity(), 'total' => $item->get_total()];
            }
            $result[] = [
                'id' => $order->get_id(), 'number' => $order->get_order_number(),
                'status' => $order->get_status(), 'date_created' => $order->get_date_created() ? $order->get_date_created()->date('c') : '',
                'total' => $order->get_total(), 'currency' => $order->get_currency(),
                'payment_method' => $order->get_payment_method_title(), 'items' => $lines,
            ];
        }
        return rest_ensure_response($result);
    }

    public function downloads($request) {
        return rest_ensure_response(wc_get_customer_available_downloads($this->user_id($request)));
    }

    public function addresses($request) {
        $items = get_user_meta($this->user_id($request), '_ark_native_saved_addresses', true);
        return rest_ensure_response(is_array($items) ? array_values($items) : []);
    }

    public function save_address($request) {
        $id = $this->user_id($request);
        $data = $request->get_json_params();
        $label = sanitize_text_field($data['label'] ?? 'Home');
        $address = [];
        foreach (['first_name','last_name','company','address_1','address_2','city','state','postcode','country','email','phone'] as $key) {
            $address[$key] = sanitize_text_field($data[$key] ?? '');
        }
        if (!$address['address_1'] || !$address['city'] || !$address['postcode'] || !$address['country']) {
            return new WP_Error('ark_address_incomplete', 'Complete the street, city, PIN code and country.', ['status' => 400]);
        }
        $items = get_user_meta($id, '_ark_native_saved_addresses', true);
        $items = is_array($items) ? array_values($items) : [];
        $address['id'] = wp_generate_uuid4();
        $address['label'] = $label;
        $items[] = $address;
        update_user_meta($id, '_ark_native_saved_addresses', $items);
        return rest_ensure_response($items);
    }

    public function delete_address($request) {
        $id = $this->user_id($request);
        $address_id = sanitize_text_field($request->get_param('id'));
        $items = get_user_meta($id, '_ark_native_saved_addresses', true);
        $items = is_array($items) ? array_values($items) : [];
        $items = array_values(array_filter($items, function($item) use ($address_id) {
            return !isset($item['id']) || $item['id'] !== $address_id;
        }));
        update_user_meta($id, '_ark_native_saved_addresses', $items);
        return rest_ensure_response($items);
    }
}
add_action('plugins_loaded', function() {
    if (class_exists('WooCommerce')) new ARK_Native_Customer_API_Bridge();
});
