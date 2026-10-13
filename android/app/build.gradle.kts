import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

val qaDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(",").filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
val qaEnabled = qaDefines.contains("CELTAS_QA=true")
val qaTarget = (project.findProperty("target") as? String).orEmpty()
    .replace('\\', '/').endsWith("lib/main_qa.dart")
val qaRequested = qaEnabled || qaTarget
val devEnabled = qaDefines.contains("CELTAS_DEV=true")
val devRequested = devEnabled || gradle.startParameter.taskNames.any {
    it.contains("Dev", ignoreCase = true)
}
val devTarget = (project.findProperty("target") as? String).orEmpty()
    .replace('\\', '/').endsWith("lib/main.dart")
check(!(qaRequested && devRequested)) { "QA and DEV cannot be combined" }
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/key.properties")
if (!qaRequested && !devRequested && keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.celtas.celtas_mobile"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    
    signingConfigs {
        if (!qaRequested && !devRequested) create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.celtas.celtas_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Normal builds retain their original variants, commands and artifact names.
    if (qaRequested) {
        flavorDimensions += "environment"
        productFlavors {
            create("qa") {
                dimension = "environment"
                applicationIdSuffix = ".qa"
            }
        }
    }
    if (devRequested) {
        flavorDimensions += "environment"
        productFlavors {
            create("dev") {
                dimension = "environment"
                applicationIdSuffix = ".dev"
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Firma de release real (keystore propio, alias `celtas-key`), leída de
            // android/app/key.properties → key.jks (ambos fuera de git). Es la clave
            // de SUBIDA de Play App Signing (SHA-1 D3:E3:09:…:BA:EC); Google re-firma
            // con la clave de la app al publicar.
            if (!qaRequested && !devRequested) signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// QA requires all three guards. It never has a release/profile variant.
androidComponents {
    beforeVariants(selector().all()) { variant ->
        val isQa = variant.productFlavors.any { it.second == "qa" }
        val isDev = variant.productFlavors.any { it.second == "dev" }
        if (isQa) {
            variant.enable = variant.buildType == "debug" && qaEnabled && qaTarget
        } else if (isDev) {
            variant.enable = variant.buildType == "debug" && devEnabled && devTarget
        } else if (qaEnabled || qaTarget || devRequested) {
            variant.enable = false
        }
    }
}
// QA does not generate Firebase configuration from the production JSON.
tasks.matching { it.name.startsWith("processQa") && it.name.endsWith("GoogleServices") }
    .configureEach { enabled = false }
// DEV uses only explicit Dart FirebaseOptions, never the root production JSON.
tasks.matching { it.name.startsWith("processDev") && it.name.endsWith("GoogleServices") }
    .configureEach { enabled = false }
tasks.withType<Copy>().matching { it.name == "copyFlutterAssetsDevDebug" }
    .configureEach {
        exclude("**/.env", "**/.env.*")
        doLast {
            check(destinationDir.walkTopDown().none {
                it.isFile && (it.name == ".env" || it.name.startsWith(".env."))
            }) { "DEV assets must not contain environment files" }
        }
    }

// Exclude configuration at the Flutter -> Android asset boundary, only for QA.
// The normal Flutter asset bundle and the original .env remain untouched.
tasks.withType<Copy>().matching { it.name == "copyFlutterAssetsQaDebug" }
    .configureEach {
        exclude("**/.env", "**/.env.*")
        doLast {
            check(destinationDir.walkTopDown().none {
                it.isFile && (it.name == ".env" || it.name.startsWith(".env."))
            }) { "QA assets must not contain environment configuration" }
        }
    }
