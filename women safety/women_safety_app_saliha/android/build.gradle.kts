buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// ---> NAMESPACE INJECTION FIX <---
subprojects {
    fun fixMissingNamespace() {
        val android = extensions.findByName("android") ?: return
        try {
            val getNamespace = android.javaClass.getMethod("getNamespace")
            val currentNamespace = getNamespace.invoke(android)
            if (currentNamespace == null || (currentNamespace as? String).isNullOrBlank()) {
                val fallbackNamespace = "com.plugin.${project.name.replace('-', '_')}"
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                setNamespace.invoke(android, fallbackNamespace)
            }
        } catch (_: Exception) {
            // Ignore if methods aren't found on custom AGP versions
        }
    }

    // Safely execute whether the subproject has already evaluated or not
    if (state.executed) {
        fixMissingNamespace()
    } else {
        afterEvaluate {
            fixMissingNamespace()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}