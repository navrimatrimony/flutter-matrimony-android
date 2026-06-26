package com.example.flutter_matrimony_android

import android.Manifest
import android.accounts.AccountManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.AccountPicker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val notificationPermissionChannel = "navri_matrimony/notification_permission"
    private val phoneNumberHintChannel = "navri_matrimony/phone_number_hint"
    private val emailHintChannel = "navri_matrimony/email_hint"
    private val nativeLocationChannel = "navri_matrimony/native_location"
    private val notificationPermissionRequestCode = 2401
    private val phoneNumberHintRequestCode = 2402
    private val emailHintRequestCode = 2403
    private val locationPermissionRequestCode = 2404
    private val locationTimeoutMillis = 20000L
    private val lastKnownLocationMaxAgeMillis = 30 * 60 * 1000L
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingPhoneNumberHintResult: MethodChannel.Result? = null
    private var pendingEmailHintResult: MethodChannel.Result? = null
    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingLocationListener: LocationListener? = null
    private var locationTimeoutRunnable: Runnable? = null
    private val locationTimeoutHandler = Handler(Looper.getMainLooper())

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeLocationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApproximateLocation" -> requestApproximateLocation(result)
                "openLocationSettings" -> openLocationSettings(result)
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

    private fun requestApproximateLocation(result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            result.error("LOCATION_PENDING", "A location request is already running.", null)
            return
        }

        if (!hasLocationPermission()) {
            pendingLocationResult = result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(
                    arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
                    locationPermissionRequestCode
                )
            } else {
                beginLocationRequest(result)
            }
            return
        }

        beginLocationRequest(result)
    }

    private fun openLocationSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun beginLocationRequest(result: MethodChannel.Result) {
        pendingLocationResult = result
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val lastKnown = bestLastKnownLocation(locationManager)
        if (lastKnown != null) {
            finishLocationSuccess(lastKnown)
            return
        }

        val provider = freshLocationProvider(locationManager)
        if (provider == null) {
            finishLocationError(
                "LOCATION_DISABLED",
                "Device location is disabled or unavailable."
            )
            return
        }

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                finishLocationSuccess(location)
            }

            override fun onProviderEnabled(provider: String) = Unit

            override fun onProviderDisabled(provider: String) = Unit

            @Deprecated("Deprecated in Android framework.")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        }

        pendingLocationListener = listener
        val timeout = Runnable {
            finishLocationError("LOCATION_TIMEOUT", "Could not get device location in time.")
        }
        locationTimeoutRunnable = timeout
        locationTimeoutHandler.postDelayed(timeout, locationTimeoutMillis)

        try {
            locationManager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        } catch (_: SecurityException) {
            finishLocationError("PERMISSION_DENIED", "Location permission was denied.")
        } catch (_: IllegalArgumentException) {
            finishLocationError("LOCATION_DISABLED", "Device location provider is unavailable.")
        }
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasFineLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun bestLastKnownLocation(locationManager: LocationManager): Location? {
        val providers = mutableListOf(LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
        if (hasFineLocationPermission()) providers.add(LocationManager.GPS_PROVIDER)
        val now = System.currentTimeMillis()

        return providers
            .mapNotNull { provider ->
                try {
                    locationManager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                } catch (_: IllegalArgumentException) {
                    null
                }
            }
            .maxByOrNull { it.time }
            ?.takeIf { it.time > 0L && now - it.time <= lastKnownLocationMaxAgeMillis }
    }

    private fun freshLocationProvider(locationManager: LocationManager): String? {
        if (isProviderEnabled(locationManager, LocationManager.NETWORK_PROVIDER)) {
            return LocationManager.NETWORK_PROVIDER
        }
        if (hasFineLocationPermission() && isProviderEnabled(locationManager, LocationManager.GPS_PROVIDER)) {
            return LocationManager.GPS_PROVIDER
        }
        return null
    }

    private fun isProviderEnabled(locationManager: LocationManager, provider: String): Boolean {
        return try {
            locationManager.isProviderEnabled(provider)
        } catch (_: Exception) {
            false
        }
    }

    private fun finishLocationSuccess(location: Location) {
        val result = pendingLocationResult ?: return
        clearLocationCallbacks()
        pendingLocationResult = null
        Thread {
            val payload = approximateLocationPayload(location)
            runOnUiThread {
                result.success(payload)
            }
        }.start()
    }

    private fun finishLocationError(code: String, message: String) {
        val result = pendingLocationResult ?: return
        clearLocationCallbacks()
        pendingLocationResult = null
        result.error(code, message, null)
    }

    private fun clearLocationCallbacks() {
        locationTimeoutRunnable?.let { locationTimeoutHandler.removeCallbacks(it) }
        locationTimeoutRunnable = null
        pendingLocationListener?.let { listener ->
            try {
                val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                locationManager.removeUpdates(listener)
            } catch (_: Exception) {
                // Nothing to clean up if the provider is already unavailable.
            }
        }
        pendingLocationListener = null
    }

    private fun approximateLocationPayload(location: Location): Map<String, Any?> {
        val address = reverseGeocode(location)
        val addressLine = if (address != null && address.maxAddressLineIndex >= 0) {
            address.getAddressLine(0)
        } else {
            null
        }

        return mapOf(
            "success" to true,
            "accuracy_meters" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
            "provider" to location.provider,
            "address_line" to addressLine,
            "country" to address?.countryName,
            "state" to address?.adminArea,
            "district" to address?.subAdminArea,
            "locality" to address?.locality,
            "sub_locality" to address?.subLocality,
            "feature_name" to address?.featureName
        )
    }

    private fun reverseGeocode(location: Location): Address? {
        if (!Geocoder.isPresent()) return null
        return try {
            @Suppress("DEPRECATION")
            Geocoder(this, Locale.getDefault())
                .getFromLocation(location.latitude, location.longitude, 1)
                ?.firstOrNull()
        } catch (_: IOException) {
            null
        } catch (_: IllegalArgumentException) {
            null
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
        when (requestCode) {
            notificationPermissionRequestCode -> {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingNotificationResult?.success(if (granted) "granted" else "denied")
                pendingNotificationResult = null
            }
            locationPermissionRequestCode -> {
                val granted = permissions.indices.any { index ->
                    grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED &&
                        permissions[index] == Manifest.permission.ACCESS_COARSE_LOCATION
                }
                val result = pendingLocationResult ?: return
                if (granted) {
                    beginLocationRequest(result)
                } else {
                    pendingLocationResult = null
                    result.error("PERMISSION_DENIED", "Location permission was denied.", null)
                }
            }
        }
    }
}
