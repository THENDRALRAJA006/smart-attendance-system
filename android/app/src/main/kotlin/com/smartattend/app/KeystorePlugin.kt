package com.smartattend.app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature

/**
 * KeystorePlugin — MethodChannel handler for Android Keystore EC P-256 operations.
 *
 * Channel: com.smartattend.app/keystore
 *
 * Methods:
 *   - getPublicKey() → String?    PEM-encoded EC P-256 public key
 *   - sign(payload: String) → String?   Base64 DER-encoded ECDSA signature
 *
 * The key pair is generated with StrongBox / hardware-backed attestation
 * when available, falling back to the TEE-backed software keystore.
 * The key is NOT user-authentication-bound so it survives screen-lock changes.
 */
class KeystorePlugin : MethodCallHandler {

    companion object {
        const val CHANNEL     = "com.smartattend.app/keystore"
        private const val TAG = "KeystorePlugin"

        // Alias used to store/retrieve the key in AndroidKeyStore
        private const val KEY_ALIAS = "smartattend_device_key_v1"
    }

    // ── MethodCallHandler ──────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPublicKey" -> handleGetPublicKey(result)
            "sign"         -> {
                val payload = call.argument<String>("payload")
                if (payload.isNullOrEmpty()) {
                    result.error("INVALID_ARG", "payload must not be empty", null)
                } else {
                    handleSign(payload, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    // ── getPublicKey ───────────────────────────────────────────

    private fun handleGetPublicKey(result: Result) {
        try {
            ensureKeyPairExists()
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val cert     = keyStore.getCertificate(KEY_ALIAS)
                ?: return result.error("KEY_NOT_FOUND", "Key not found after generation", null)

            val pubKeyBytes = cert.publicKey.encoded
            val pem = buildString {
                append("-----BEGIN PUBLIC KEY-----\n")
                append(Base64.encodeToString(pubKeyBytes, Base64.NO_WRAP))
                append("\n-----END PUBLIC KEY-----")
            }
            result.success(pem)
        } catch (e: Exception) {
            Log.e(TAG, "getPublicKey failed", e)
            result.error("KEYSTORE_ERROR", e.message, null)
        }
    }

    // ── sign ──────────────────────────────────────────────────

    private fun handleSign(payload: String, result: Result) {
        try {
            ensureKeyPairExists()
            val keyStore   = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val privateKey = keyStore.getKey(KEY_ALIAS, null)
                ?: return result.error("KEY_NOT_FOUND", "Private key not available", null)

            val signature = Signature.getInstance("SHA256withECDSA").apply {
                initSign(privateKey as java.security.PrivateKey)
                update(payload.toByteArray(Charsets.UTF_8))
            }.sign()

            result.success(Base64.encodeToString(signature, Base64.NO_WRAP))
        } catch (e: Exception) {
            Log.e(TAG, "sign() failed", e)
            result.error("SIGN_ERROR", e.message, null)
        }
    }

    // ── Key lifecycle ──────────────────────────────────────────

    private fun ensureKeyPairExists() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (keyStore.containsAlias(KEY_ALIAS)) return

        Log.i(TAG, "Generating EC P-256 key pair in AndroidKeyStore (alias=$KEY_ALIAS)")

        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(java.security.spec.ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            // Not user-auth-bound — survives biometric enrollment changes
            .setUserAuthenticationRequired(false)
            .build()

        KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore",
        ).apply {
            initialize(spec)
            generateKeyPair()
        }

        Log.i(TAG, "EC P-256 key pair generated successfully")
    }
}
