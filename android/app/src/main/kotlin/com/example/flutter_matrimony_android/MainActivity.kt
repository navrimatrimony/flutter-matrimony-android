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
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.AccountPicker
import com.google.android.gms.common.api.ApiException
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
    private val googleEmailVerificationRequestCode = 2405
    private val locationTimeoutMillis = 20000L
    private val lastKnownLocationMaxAgeMillis = 30 * 60 * 1000L
    private val relaxedLastKnownLocationMaxAgeMillis = 2 * 60 * 60 * 1000L
    private val relaxedLastKnownMaxAccuracyMeters = 20_000f
    private val relaxedFallbackDelayMillis = 4500L
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingPhoneNumberHintResult: MethodChannel.Result? = null
    private var pendingEmailHintResult: MethodChannel.Result? = null
    private var pendingGoogleEmailVerificationResult: MethodChannel.Result? = null
    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingLocationLocale: String? = null
    private var pendingLocationListener: LocationListener? = null
    private var requestedFineLocationUpgrade = false
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
                "requestGoogleEmailVerification" -> requestGoogleEmailVerification(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeLocationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApproximateLocation" -> requestApproximateLocation(
                    result,
                    call.argument<String>("locale")
                )
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

    private fun requestGoogleEmailVerification(result: MethodChannel.Result) {
        if (pendingGoogleEmailVerificationResult != null) {
            result.success(null)
            return
        }

        pendingGoogleEmailVerificationResult = result
        try {
            val builder = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestEmail()
            val clientId = googleServerClientId()
            if (clientId != null) {
                builder.requestIdToken(clientId)
            }
            val options = builder.build()
            val client = GoogleSignIn.getClient(this, options)
            @Suppress("DEPRECATION")
            startActivityForResult(client.signInIntent, googleEmailVerificationRequestCode)
        } catch (_: Exception) {
            finishGoogleEmailVerification(null)
        }
    }

    private fun googleServerClientId(): String? {
        val id = resources.getIdentifier("default_web_client_id", "string", packageName)
        if (id == 0) {
            return null
        }
        return try {
            getString(id).trim().ifEmpty { null }
        } catch (_: Exception) {
            null
        }
    }

    private fun requestApproximateLocation(result: MethodChannel.Result, requestedLocale: String?) {
        if (pendingLocationResult != null) {
            result.error("LOCATION_PENDING", "A location request is already running.", null)
            return
        }

        pendingLocationLocale = requestedLocale
        if (shouldRequestLocationPermission()) {
            pendingLocationResult = result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestedFineLocationUpgrade = true
                requestPermissions(
                    locationPermissionsToRequest(),
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
        val lastKnown = bestLastKnownLocation(
            locationManager,
            maxAgeMillis = lastKnownLocationMaxAgeMillis,
            maxAccuracyMeters = null
        )
        if (lastKnown != null) {
            finishLocationSuccess(lastKnown)
            return
        }

        val providers = freshLocationProviders(locationManager)
        if (providers.isEmpty()) {
            finishLocationError(
                "LOCATION_DISABLED",
                "Device location is disabled or unavailable."
            )
            return
        }

        val relaxedFallback = bestLastKnownLocation(
            locationManager,
            maxAgeMillis = relaxedLastKnownLocationMaxAgeMillis,
            maxAccuracyMeters = relaxedLastKnownMaxAccuracyMeters
        )

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
            val fallback = relaxedFallback ?: bestLastKnownLocation(
                    locationManager,
                    maxAgeMillis = relaxedLastKnownLocationMaxAgeMillis,
                    maxAccuracyMeters = relaxedLastKnownMaxAccuracyMeters
                )
            if (fallback != null) {
                finishLocationSuccess(fallback)
            } else {
                finishLocationError("LOCATION_TIMEOUT", "Could not get device location in time.")
            }
        }
        locationTimeoutRunnable = timeout
        locationTimeoutHandler.postDelayed(
            timeout,
            if (relaxedFallback != null) relaxedFallbackDelayMillis else locationTimeoutMillis
        )

        var requested = false
        try {
            for (provider in providers) {
                try {
                    if (requestCurrentLocation(locationManager, provider)) {
                        requested = true
                    }
                    locationManager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
                    requested = true
                } catch (_: IllegalArgumentException) {
                    // Try the next enabled provider.
                }
            }
        } catch (_: SecurityException) {
            finishLocationError("PERMISSION_DENIED", "Location permission was denied.")
        }

        if (!requested && pendingLocationResult != null) {
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

    private fun shouldRequestLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        if (!hasLocationPermission()) return true
        return !hasFineLocationPermission() && !requestedFineLocationUpgrade
    }

    private fun locationPermissionsToRequest(): Array<String> {
        return arrayOf(
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
    }

    private fun hasFineLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun bestLastKnownLocation(
        locationManager: LocationManager,
        maxAgeMillis: Long,
        maxAccuracyMeters: Float?
    ): Location? {
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
            .filter { it.time > 0L && now - it.time <= maxAgeMillis }
            .filter { maxAccuracyMeters == null || !it.hasAccuracy() || it.accuracy <= maxAccuracyMeters }
            .maxByOrNull { it.time }
    }

    private fun freshLocationProviders(locationManager: LocationManager): List<String> {
        val providers = mutableListOf<String>()
        if (isProviderEnabled(locationManager, LocationManager.NETWORK_PROVIDER)) {
            providers.add(LocationManager.NETWORK_PROVIDER)
        }
        if (isProviderEnabled(locationManager, LocationManager.PASSIVE_PROVIDER)) {
            providers.add(LocationManager.PASSIVE_PROVIDER)
        }
        if (hasFineLocationPermission() && isProviderEnabled(locationManager, LocationManager.GPS_PROVIDER)) {
            providers.add(LocationManager.GPS_PROVIDER)
        }
        return providers
    }

    private fun isProviderEnabled(locationManager: LocationManager, provider: String): Boolean {
        return try {
            locationManager.isProviderEnabled(provider)
        } catch (_: Exception) {
            false
        }
    }

    private fun requestCurrentLocation(
        locationManager: LocationManager,
        provider: String
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            locationManager.getCurrentLocation(
                provider,
                CancellationSignal(),
                mainExecutor
            ) { location ->
                if (location != null) {
                    finishLocationSuccess(location)
                }
            }
            true
        } catch (error: SecurityException) {
            throw error
        } catch (_: Exception) {
            false
        }
    }

    private fun finishLocationSuccess(location: Location) {
        val result = pendingLocationResult ?: return
        val requestedLocale = pendingLocationLocale
        clearLocationCallbacks()
        pendingLocationResult = null
        pendingLocationLocale = null
        Thread {
            val payload = approximateLocationPayload(location, requestedLocale)
            runOnUiThread {
                result.success(payload)
            }
        }.start()
    }

    private fun finishLocationError(code: String, message: String) {
        val result = pendingLocationResult ?: return
        clearLocationCallbacks()
        pendingLocationResult = null
        pendingLocationLocale = null
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

    private fun approximateLocationPayload(location: Location, requestedLocale: String?): Map<String, Any?> {
        val displayLocale = locationDisplayLocale(requestedLocale)
        val displayAddress = reverseGeocode(location, displayLocale)
        val englishAddress = if (displayLocale.language == Locale.ENGLISH.language) {
            displayAddress
        } else {
            reverseGeocode(location, Locale.ENGLISH)
        }
        val address = displayAddress ?: englishAddress
        val addressLine = addressLine(displayAddress) ?: addressLine(englishAddress)

        return mapOf(
            "success" to true,
            "accuracy_meters" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
            "provider" to location.provider,
            "address_line" to addressLine,
            "address_line_en" to addressLine(englishAddress),
            "country" to address?.countryName,
            "country_en" to englishAddress?.countryName,
            "state" to address?.adminArea,
            "state_en" to englishAddress?.adminArea,
            "district" to address?.subAdminArea,
            "district_en" to englishAddress?.subAdminArea,
            "locality" to address?.locality,
            "locality_en" to englishAddress?.locality,
            "sub_locality" to address?.subLocality,
            "sub_locality_en" to englishAddress?.subLocality,
            "feature_name" to address?.featureName,
            "feature_name_en" to englishAddress?.featureName
        )
    }

    private fun addressLine(address: Address?): String? {
        return if (address != null && address.maxAddressLineIndex >= 0) {
            address.getAddressLine(0)
        } else {
            null
        }
    }

    private fun locationDisplayLocale(requestedLocale: String?): Locale {
        return when (requestedLocale?.trim()?.lowercase(Locale.US)) {
            "mr", "marathi" -> Locale("mr", "IN")
            "en", "english" -> Locale.ENGLISH
            else -> Locale.getDefault()
        }
    }

    private fun reverseGeocode(location: Location, locale: Locale): Address? {
        if (!Geocoder.isPresent()) return null
        return try {
            @Suppress("DEPRECATION")
            Geocoder(this, locale)
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

    private fun finishGoogleEmailVerification(profile: Map<String, Any?>?) {
        pendingGoogleEmailVerificationResult?.success(profile)
        pendingGoogleEmailVerificationResult = null
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
            googleEmailVerificationRequestCode -> {
                val profile = if (resultCode == Activity.RESULT_OK && data != null) {
                    try {
                        val account = GoogleSignIn.getSignedInAccountFromIntent(data)
                            .getResult(ApiException::class.java)
                        mapOf(
                            "email" to account.email,
                            "id_token" to account.idToken,
                            "is_google_account" to true
                        )
                    } catch (_: Exception) {
                        null
                    }
                } else {
                    null
                }
                finishGoogleEmailVerification(profile)
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
                        (
                            permissions[index] == Manifest.permission.ACCESS_COARSE_LOCATION ||
                                permissions[index] == Manifest.permission.ACCESS_FINE_LOCATION
                        )
                }
                val result = pendingLocationResult ?: return
                if (granted) {
                    beginLocationRequest(result)
                } else {
                    pendingLocationResult = null
                    pendingLocationLocale = null
                    result.error("PERMISSION_DENIED", "Location permission was denied.", null)
                }
            }
        }
    }
}
