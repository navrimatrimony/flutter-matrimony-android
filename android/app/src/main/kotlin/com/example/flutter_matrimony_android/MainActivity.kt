package com.example.flutter_matrimony_android

import android.Manifest
import android.accounts.AccountManager
import android.app.Activity
import android.content.pm.PackageManager
import android.content.Intent
import android.content.IntentSender
import android.os.Build
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.AccountPicker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationPermissionChannel = "navri_matrimony/notification_permission"
    private val phoneNumberHintChannel = "navri_matrimony/phone_number_hint"
    private val emailHintChannel = "navri_matrimony/email_hint"
    private val notificationPermissionRequestCode = 2401
    private val phoneNumberHintRequestCode = 2402
    private val emailHintRequestCode = 2403
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingPhoneNumberHintResult: MethodChannel.Result? = null
    private var pendingEmailHintResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationPermissionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            phoneNumberHintChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPhoneNumberHint" -> requestPhoneNumberHint(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            emailHintChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestEmailHint" -> requestEmailHint(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("not_required")
            return
        }

        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }

        if (pendingNotificationResult != null) {
            result.success("pending")
            return
        }

        pendingNotificationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode
        )
    }

    private fun requestPhoneNumberHint(result: MethodChannel.Result) {
        if (pendingPhoneNumberHintResult != null) {
            result.success(null)
            return
        }

        pendingPhoneNumberHintResult = result
        val request = GetPhoneNumberHintIntentRequest.builder().build()
        Identity.getSignInClient(this)
            .getPhoneNumberHintIntent(request)
            .addOnSuccessListener { pendingIntent ->
                try {
                    @Suppress("DEPRECATION")
                    startIntentSenderForResult(
                        pendingIntent.intentSender,
                        phoneNumberHintRequestCode,
                        null,
                        0,
                        0,
                        0,
                        null
                    )
                } catch (_: IntentSender.SendIntentException) {
                    finishPhoneNumberHint(null)
                }
            }
            .addOnFailureListener {
                finishPhoneNumberHint(null)
            }
    }

    private fun requestEmailHint(result: MethodChannel.Result) {
        if (pendingEmailHintResult != null) {
            result.success(null)
            return
        }

        pendingEmailHintResult = result
        try {
            @Suppress("DEPRECATION")
            val intent = AccountPicker.newChooseAccountIntent(
                null,
                null,
                arrayOf("com.google"),
                true,
                null,
                null,
                null,
                null
            )
            @Suppress("DEPRECATION")
            startActivityForResult(intent, emailHintRequestCode)
        } catch (_: Exception) {
            finishEmailHint(null)
        }
    }

    private fun finishPhoneNumberHint(phoneNumber: String?) {
        pendingPhoneNumberHintResult?.success(phoneNumber)
        pendingPhoneNumberHintResult = null
    }

    private fun finishEmailHint(email: String?) {
        pendingEmailHintResult?.success(email)
        pendingEmailHintResult = null
    }

    @Deprecated("Deprecated in Android framework, still used for Play Services hint intents.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            phoneNumberHintRequestCode -> {
                val phoneNumber = if (resultCode == Activity.RESULT_OK && data != null) {
                    try {
                        Identity.getSignInClient(this).getPhoneNumberFromIntent(data)
                    } catch (_: Exception) {
                        null
                    }
                } else {
                    null
                }
                finishPhoneNumberHint(phoneNumber)
            }
            emailHintRequestCode -> {
                val email = if (resultCode == Activity.RESULT_OK) {
                    data?.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                } else {
                    null
                }
                finishEmailHint(email)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationPermissionRequestCode) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingNotificationResult?.success(if (granted) "granted" else "denied")
        pendingNotificationResult = null
    }
}
