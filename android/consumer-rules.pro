# Public E-IMZO SDK API used by this plugin
-keep public class uz.eimzo.sdk.EImzoSDK { public *; }
-keep public class uz.eimzo.sdk.EImzoSDK$Companion { public *; }
-keep public class uz.eimzo.sdk.EImzoConfig { *; }
-keep public interface uz.eimzo.sdk.ImportKeyCallback { *; }
-keep public interface uz.eimzo.sdk.SignCallback { *; }
-keep public interface uz.eimzo.sdk.CertInfoCallback { *; }
-keep public class uz.eimzo.sdk.models.PfxKey { *; }
-keep public class uz.eimzo.sdk.models.CertInfo { *; }
-keep public class uz.eimzo.sdk.models.QrHashData { *; }
-keep public enum uz.eimzo.sdk.models.KeyType { *; }
-keep public class uz.eimzo.sdk.models.SignResult { *; }
-keep public class uz.eimzo.sdk.models.SignResult$Success { *; }
-keep public class uz.eimzo.sdk.models.SignResult$Failure { *; }
-keep public class uz.eimzo.sdk.license.LicenseResult { *; }
-keep class uz.eimzo.sdk.license.BlockedAppActivity { <init>(...); }
-keep public class uz.eimzo.sdk.ui.NfcWaitBottomSheet { public *; }
-keep public class uz.eimzo.sdk.ui.NfcWaitBottomSheet$NfcState { *; }
-keep public class uz.eimzo.sdk.ui.LoadingOverlay { public *; }

# Plugin itself
-keep class uz.peachdev.eimzo_flutter.** { *; }

# Bundled pfx2qr Java wrapper + go-mobile JNI bridge classes. libgojni.so
# looks up go.Seq.getRef etc. by name — R8 must NOT rename/strip them or
# PFX parsing crashes at runtime with "failed to find method Seq.getRef"
# (SIGABRT inside Java_go_Seq_init).
-keep class pfx2qr.** { *; }
-keep class go.** { *; }
-keepclassmembers class go.** { *; }
-dontwarn pfx2qr.**
-dontwarn go.**
