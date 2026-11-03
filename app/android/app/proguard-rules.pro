# Release shrinking (R8) removed or renamed classes that libraries load by
# name, and the app died at start-up inside WorkManager's initializer
# ("Failed to create an instance of androidx.work.impl.WorkDatabase").
# WorkManager arrives with the ads SDK and uses a Room database whose
# implementation class is generated and found by name.

-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * implements androidx.room.RoomDatabaseConstructor { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>(...);
}
-dontwarn androidx.room.paging.**
