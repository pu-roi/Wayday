# Navigation SDK 7.9.0 reflectively constructs package-private alt.k in alt.ax.b.
# R8 moved ax out of that package in release builds, causing IllegalAccessException.
# Preserve this loader and method location; the SDK already keeps its registries.
# Revalidate this internal boundary when upgrading the pinned Navigation SDK.
-keep class com.google.android.libraries.navigation.internal.alt.ax {
    *;
}
