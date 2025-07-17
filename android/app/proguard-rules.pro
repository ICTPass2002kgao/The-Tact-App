# Rules for Stripe Push Provisioning to prevent R8 from stripping necessary classes.
# Keep all classes within the pushProvisioning package.
-keep class com.stripe.android.pushProvisioning.** { *; }

# Keep all classes within the reactnativestripesdk pushprovisioning if referenced by the Flutter plugin.
-keep class com.reactnativestripesdk.pushprovisioning.** { *; }

# Don't warn if some related classes are not found, which can happen with optional features.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**

# It's good practice to also include general Stripe rules if not already present
# These often come from the flutter_stripe plugin itself or official Stripe docs.
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**